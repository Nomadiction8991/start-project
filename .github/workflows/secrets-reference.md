# Secrets Reference

Guia de cadastro em `Settings > Secrets and variables > Actions`.

## Fluxo

1. `build-image.yml` lê `APP_NAME` do `.env.example` da raiz, monta o pacote Laravel e gera o artefato `laravel-package` com arquivos ocultos incluidos, porque o `.env` interno do Laravel precisa viajar no pacote.
2. `ftp-deploy.yml` baixa o artefato, lê `APP_URL` do `.env` empacotado, calcula a pasta remota e publica via `SamKirkland/FTP-Deploy-Action` com state file persistido por cache para subir so o delta.
3. `ssh-finalize.yml` baixa o destino calculado, entra primeiro em `SSH_PATH` e depois na pasta criada pelo FTP, gera `APP_KEY` se faltar e roda `php artisan migrate --force`.

## Regras do deploy

- `DOMINIO` vira base para FTP, SSH e `APP_URL`.
- O nome remoto nasce de `APP_NAME` tratado para minusculas e apenas letras `a-z`.
- A pasta final no servidor fica em `SSH_PATH/<app_name_tratado>.<DOMINIO>`.
- O FTP usa o host de `APP_URL` do artefato para criar a pasta com dominio completo.
- O FTP usa `state-name` + cache para lembrar o ultimo sync e enviar so o que mudou.
- Valores do `.env` com caracteres especiais sao serializados com aspas quando necessario.
- O FTP nao apaga tudo. Ele sincroniza e envia somente arquivos novos ou alterados.
- O SSH finaliza o deploy dentro da mesma pasta criada pelo FTP.

## Secrets obrigadas

| Secret | Uso | Workflow |
|---|---|---|
| `DOMINIO` | Dominio base do servidor. Tambem vira host FTP e SSH. | `build-image.yml`, `ftp-deploy.yml`, `ssh-finalize.yml` |
| `FTP_USERNAME` | Usuario FTP. | `ftp-deploy.yml` |
| `FTP_PASSWORD` | Senha FTP. | `ftp-deploy.yml` |
| `DB_HOST` | Host do banco de dados. | `build-image.yml` |
| `DB_PORT` | Porta do banco de dados. | `build-image.yml` |
| `DB_DATABASE` | Nome do banco de dados. | `build-image.yml` |
| `DB_USERNAME` | Usuario do banco de dados. | `build-image.yml` |
| `DB_PASSWORD` | Senha do banco de dados. | `build-image.yml` |
| `SSH_USERNAME` | Usuario SSH. | `ssh-finalize.yml` |
| `SSH_PORT` | Porta SSH. | `ssh-finalize.yml` |
| `SSH_PATH` | Pasta raiz no servidor. Ex: `/domains`. | `ssh-finalize.yml` |
| `SSH_KEY` | Chave privada SSH completa. | `ssh-finalize.yml` |

## Variaveis de origem

| Variavel | Origem | Observacao |
|---|---|---|
| `APP_NAME` | `.env.example` da raiz | Nao e secret. Define a pasta Laravel no repo. |
| `APP_URL` | Calculada no build | `https://{APP_NAME_TRATADO}.{DOMINIO}`. |
| `APP_ENV` | Fixo no build | Sempre `production`. |
| `DB_CONNECTION` | Fixo no build | Sempre `mysql`. |
| `APP_KEY` | Gerada no servidor | O workflow `ssh-finalize.yml` gera se estiver vazia. |
