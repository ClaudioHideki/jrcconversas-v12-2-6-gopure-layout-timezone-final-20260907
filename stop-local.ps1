$ErrorActionPreference = 'Stop'
docker compose -p gopure-crm-local -f docker-compose.yaml down
Write-Host "GoPure local parado. Os volumes/banco foram preservados." -ForegroundColor Green
