$ErrorActionPreference = 'Stop'
$Project = 'gopure-crm-local'
$Compose = 'docker-compose.yaml'

function Assert-PortFree([int]$Port, [string]$Name) {
  $used = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
  if ($used) {
    throw "Porta $Port ($Name) já está ocupada. Feche o serviço que usa essa porta ou altere docker-compose.yaml."
  }
}

Write-Host "[GoPure] Validando Docker..." -ForegroundColor Cyan
docker info | Out-Null

Assert-PortFree 3026 'Rails/JRC Conversas'
Assert-PortFree 3056 'Vite'
Assert-PortFree 55466 'PostgreSQL'
Assert-PortFree 56416 'Redis'
Assert-PortFree 1046 'SMTP MailHog'
Assert-PortFree 8046 'MailHog Web'

Write-Host "[GoPure] Build das imagens (a primeira vez pode demorar)..." -ForegroundColor Cyan
docker compose -p $Project -f $Compose build rails vite

Write-Host "[GoPure] Subindo PostgreSQL, Redis e MailHog..." -ForegroundColor Cyan
docker compose -p $Project -f $Compose up -d postgres redis mailhog

Write-Host "[GoPure] Preparando banco e migrations..." -ForegroundColor Cyan
docker compose -p $Project -f $Compose run --rm --no-deps rails bundle exec rails db:chatwoot_prepare

Write-Host "[GoPure] Aplicando bootstrap local (nome, usuário e features)..." -ForegroundColor Cyan
docker compose -p $Project -f $Compose run --rm --no-deps rails bundle exec rails runner script/local_gopure_bootstrap.rb

Write-Host "[GoPure] Subindo Rails, Vite e Sidekiq..." -ForegroundColor Cyan
docker compose -p $Project -f $Compose up -d rails vite sidekiq

Write-Host "[GoPure] Aguardando aplicação responder..." -ForegroundColor Cyan
$ok = $false
for ($i=0; $i -lt 60; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:3026' -TimeoutSec 3
    if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok = $true; break }
  } catch {}
  Start-Sleep -Seconds 2
}

Write-Host ""
docker compose -p $Project -f $Compose ps
Write-Host ""
if ($ok) {
  Write-Host "GoPure local está no ar: http://localhost:3026" -ForegroundColor Green
  Write-Host "MailHog: http://localhost:8046" -ForegroundColor Green
  Write-Host "Login: admin@gopure.com.br" -ForegroundColor Green
  Write-Host "Senha: Password1!" -ForegroundColor Green
} else {
  Write-Host "Os containers subiram, mas o Rails ainda não respondeu em http://localhost:3026." -ForegroundColor Yellow
  Write-Host "Veja os logs com: docker compose -p $Project -f $Compose logs -f rails vite sidekiq" -ForegroundColor Yellow
}
