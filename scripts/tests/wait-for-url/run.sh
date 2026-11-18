#!/usr/bin/env bash
# Testes do wait-for-url.sh com servidores HTTP/HTTPS locais e certificado autoassinado.
# Nao usa Python. Requer bash, curl, node e openssl.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DIR/../../wait-for-url.sh"
WORK="$(mktemp -d)"
export WORK
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$WORK"; }
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -days 1 -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null \
  || { echo "FAIL: nao foi possivel gerar o certificado de teste"; exit 1; }

cat > "$WORK/srv.js" <<'JS'
const [, , proto, port, code] = process.argv;
const fs = require('fs');
const handler = (req, res) => { res.statusCode = Number(code); res.end('ok'); };
const srv = proto === 'https'
  ? require('https').createServer({ key: fs.readFileSync(process.env.WORK + '/key.pem'), cert: fs.readFileSync(process.env.WORK + '/cert.pem') }, handler)
  : require('http').createServer(handler);
srv.listen(Number(port), '127.0.0.1');
JS

start() { node "$WORK/srv.js" "$@" & PIDS+=($!); sleep 1; }
start http 18080 200
start http 18081 500
start http 18082 404
start http 18083 401
start https 18443 200

pass=0; failn=0
expect() { # nome, rc esperado, texto que deve aparecer (opcional), comando...
  local name="$1" want="$2" grepfor="$3"; shift 3
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ "$rc" -eq "$want" && ( -z "$grepfor" || "$out" == *"$grepfor"* ) ]]; then
    pass=$((pass+1)); echo "PASS $name (rc=$rc)"
  else
    failn=$((failn+1)); echo "FAIL $name: esperado rc=$want, obtido rc=$rc"; echo "$out" | tail -3
  fi
}

expect "http 200 e pronto" 0 "" bash "$SCRIPT" http://127.0.0.1:18080/ 3
expect "http 404 nao e pronto (prazo acaba)" 1 "nao ficou pronto" bash "$SCRIPT" http://127.0.0.1:18082/ 2
expect "http 401 (protegido) conta como pronto" 0 "" bash "$SCRIPT" http://127.0.0.1:18083/ 3
expect "http 500 nao e pronto (prazo acaba)" 1 "nao ficou pronto" bash "$SCRIPT" http://127.0.0.1:18081/ 2
expect "porta sem servidor: prazo acaba" 1 "Failed to connect" bash "$SCRIPT" http://127.0.0.1:18999/ 2
expect "https autoassinado sem CA: falha TLS, nao vira pronto" 1 "certificate" bash "$SCRIPT" https://127.0.0.1:18443/ 2
expect "https com CA_CERT_FILE: pronto" 0 "" env CA_CERT_FILE="$WORK/cert.pem" bash "$SCRIPT" https://127.0.0.1:18443/ 3
expect "CA_CERT_FILE inexistente: erro de configuracao (rc 2)" 2 "nao encontrado" env CA_CERT_FILE="$WORK/nao-existe.pem" bash "$SCRIPT" https://127.0.0.1:18443/ 2
expect "script nao desabilita TLS (sem curl -k)" 0 "" bash -c "! grep -E 'curl[^|]* -[a-zA-Z]*k' '$SCRIPT'"

echo "resumo: $pass ok, $failn falha(s)"
[[ $failn -eq 0 ]]
