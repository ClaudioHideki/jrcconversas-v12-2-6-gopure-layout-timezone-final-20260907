<!-- jrc-operational-init:v1 -->
# Visão do sistema — JRC Conversas GoPure

## Propósito e fronteira

Implantação GoPure com identidade e configurações próprias; atualizações de campanhas não autorizam copiar dados de outra empresa.

**Stack:** Ruby/Rails, Vue, PostgreSQL, Redis/Sidekiq, canais WhatsApp e campanhas.

**Natureza:** Brownfield. **Tipo de raiz:** application.

## Fluxo lógico

Lista/conteúdo → campanha → caixa remetente selecionada → provedor → eventos de estado; entrega precisa de confirmação própria.

Esta é uma visão de responsabilidades baseada em fontes locais, não um levantamento dos hosts efetivos. Versão em execução, topologia física, portas produtivas e imagem implantada não foram verificadas neste bootstrap.

## Controle de versões

- Data da leitura: 2026-11-13.
- Branch local: `codex/gopure-campanhas-texto-imagem-20261104`.
- HEAD de origem antes da documentação: `5837c8c6150c5da0dd7609ba32f942cdda78b82f`.
- Origem Git: `https://github.com/ClaudioHideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907.git`.
- [Contexto e versões declaradas](repository-context-init-v1.json).

Esse HEAD é a base documental observada e não será atualizado para fingir versão produtiva. A revisão documental, o software, o commit, a imagem publicada e a imagem em execução são informações distintas.

## Fontes atuais

- [AGENTS.md](<../../AGENTS.md>)
- [README.md](<../../README.md>)
- [package.json](<../../package.json>)
- [Gemfile](<../../Gemfile>)
- [db/schema.rb](<../../db/schema.rb>)

## Pendências conhecidas

- Homologar envio de texto e imagem somente com o escopo de teste autorizado da GoPure.
- Reconciliar correções genéricas do LAB2 preservando layout e timezone específicos.

O padrão de arquitetura JRC completo usa prancha integrada, fluxos, runtimes e quadro de versões com fontes; a referência visual aprovada é a arquitetura R03/R04 de 13/11/2026. Este índice não substitui aquelas pranchas nem os planos existentes.
