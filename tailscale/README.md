# ACL do Tailscale como codigo

- `policy.hujson`: a politica do tailnet. Edite aqui, abra um PR, e o merge na `main` aplica.
- `.github/workflows/tailscale-acl.yml`: `test` no PR (roda a secao `tests`) e `apply` na `main` (`tailscale/gitops-acl-action@v1`).
- A secao `tests` garante que o runner do CD (`tag:github`) so alcanca `192.168.1.2:443`. O repositorio e publico; o IP e da LAN domestica.

## Configuracao (uma vez, no console do Tailscale)

1. **Settings, Trust credentials, Credential, OpenID Connect**: Issuer GitHub, Subject
   `repo:guilhermelinosp@121059870/templates@1214325533:*`, escopo **`policy_file`** (sem tag).
   E uma credencial **diferente** da do CD (`auth_keys` + `tag:github`): cada uma com o menor poder possivel.
2. Cadastre as **variables** neste repositorio: `TS_ACL_CLIENT_ID` (Client ID), `TS_ACL_AUDIENCE` (Audience) e
   `TS_TAILNET` (`-` usa o tailnet da propria credencial).
3. Opcional: em **Settings, Policy file management**, ative **Prevent edits in the admin console** e preencha
   **External reference** com a URL deste repositorio.
