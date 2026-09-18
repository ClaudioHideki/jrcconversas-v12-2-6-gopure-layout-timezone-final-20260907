# GoPure CRM — execução local

Este pacote foi preparado para Docker Desktop no Windows com portas separadas das bases anteriores.

## Portas
- JRC Conversas / Rails: http://localhost:3026
- Vite: 3056
- PostgreSQL: 55466
- Redis: 56416
- MailHog SMTP: 1046
- MailHog Web: http://localhost:8046

## Login local
- E-mail: `admin@gopure.com.br`
- Senha: `Password1!`

## Subir
Abra PowerShell dentro desta pasta e execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\start-local.ps1
```

Na primeira execução o Docker precisa construir as imagens, preparar o banco, rodar as migrations, aplicar o bootstrap GoPure e iniciar Rails/Vite/Sidekiq.

## Ver logs
```powershell
docker compose -p gopure-crm-local -f docker-compose.yaml logs -f rails vite sidekiq
```

## Parar sem apagar dados
```powershell
.\stop-local.ps1
```

## Resetar somente esta homologação local
```powershell
.\reset-local.ps1
```

O projeto Compose usa o nome `gopure-crm-local`, então volumes e containers ficam separados dos outros projetos locais.
