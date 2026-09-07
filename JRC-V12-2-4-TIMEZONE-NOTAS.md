# JRC V12.2.4 — Correção de timezone das Campanhas

Base: `jrcconversas-v12-2-3-nico-crm-campanhas-20260906`

## Alteração
- Adicionada configuração `APP_TIME_ZONE` no Rails.
- `Time.zone`, `Time.current` e `Time.zone.parse` passam a respeitar o fuso configurado.
- ActiveRecord continua persistindo timestamps em UTC (`default_timezone = :utc`).
- Isso corrige o cálculo de janelas/agendamentos do módulo JRC Campanhas sem alterar o banco para horário local.

## GoPure
Adicionar ao `.env` do ambiente:

```env
APP_TIME_ZONE=America/Sao_Paulo
```

Depois gerar a imagem e redeployar Rails + Sidekiq.

## Validação após deploy

```bash
cd /app
bundle exec rails runner 'puts "Rails=#{Time.zone.name} #{Time.current}"; puts "DB timezone=#{ActiveRecord.default_timezone}"'
```

Esperado para GoPure:
- Rails: `America/Sao_Paulo`
- horário local com offset `-0300`
- ActiveRecord: `utc`

Observação: jobs que já estavam no `ScheduledSet` antes do deploy mantêm o instante antigo; testar com uma campanha nova.
