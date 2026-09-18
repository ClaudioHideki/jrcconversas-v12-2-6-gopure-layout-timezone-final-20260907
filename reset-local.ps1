$ErrorActionPreference = 'Stop'
Write-Host "ATENÇÃO: isto apaga SOMENTE os volumes do projeto local gopure-crm-local." -ForegroundColor Yellow
$ans = Read-Host "Digite RESET para continuar"
if ($ans -ne 'RESET') { Write-Host 'Cancelado.'; exit 0 }
docker compose -p gopure-crm-local -f docker-compose.yaml down -v --remove-orphans
Write-Host "Ambiente local removido. Execute .\start-local.ps1 para recriar." -ForegroundColor Green
