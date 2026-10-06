# ACL do Tailscale como codigo

- `policy.hujson`: a politica do tailnet. Edite aqui, abra um PR, e o merge na `main` aplica.
- `.github/workflows/tailscale-acl.yml`: no merge na `main`, o `tailscale/gitops-acl-action@v1` valida, roda a secao `tests` e so entao aplica. Nao ha teste em PR (o environment `production` so aceita a `main`).
- A secao `tests` garante que o runner do CD (`tag:github`) so alcanca `192.168.1.2:443`. O repositorio e publico; o IP e da LAN domestica.

## Configuracao (uma vez, no console do Tailscale)

Uma credencial so, a mesma do CD: **Settings, Trust credentials**, abra a credencial OIDC (Issuer GitHub, Subject
`repo:guilhermelinosp@121059870/templates@1214325533:environment:production`) e garanta os escopos **`auth_keys`** (tag `tag:github`)
e **`policy_file`**. Cadastre a variable `TS_TAILNET` (`-` usa o tailnet da propria credencial) neste repositorio; `TS_CLIENT_ID` e
`TS_AUDIENCE` ja existem. Opcional: **Policy file management**, ative **Prevent edits in the admin console**.

Troca consciente: a credencial unica pode entrar na rede e editar a ACL; o que protege e a regra de branch da `main` e o environment.
