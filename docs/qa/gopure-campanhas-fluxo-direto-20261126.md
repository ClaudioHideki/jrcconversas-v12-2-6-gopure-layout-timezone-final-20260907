# GoPure — Fluxo direto e contraste de campanhas

Base preservada: `e269a3476a2ede72bd284e300379059193279527`.
Branch: `codex/gopure-campanhas-fluxo-direto-20261126`.

## Escopo implementado

Disparos como tela inicial; aba/painel de consentimentos e filtro de Cadastro Mestre retirados do assistente; novas campanhas com São Paulo fixo; textos e gráficos com contraste reforçado. Elegibilidade de todas as origens sem cadastro positivo obrigatório, preservando recusas, blacklist, bloqueios, isolamento e confirmação do público selecionado.

Consentimentos históricos não são criados, apagados nem atualizados para simular autorização. As APIs históricas permanecem disponíveis. Autorizações pontuais de teste existentes mantêm seus limites; um teste novo sem esses registros usa confirmação explícita e idempotência. Regras do provedor e aprovação humana da campanha permanecem.

## Verificações locais

- Backend final: 217 exemplos aprovados, incluindo Meta/Evolution/Broker, consentimentos históricos, mídias e rastreamento. Testes antigos que exigiam cadastro positivo foram adaptados à nova decisão; bloqueios, recusas e limites pontuais continuam cobertos.
- Complemento: 16 exemplos aprovados, cobrindo etiquetas, caixas, CRM, contatos e lista sanitizada sem cadastro prévio, além da regressão de seleção manual. Com 511 contatos sem consentimento cadastrado, somente os quatro selecionados entram na execução e nas quatro chamadas interceptadas ao transporte oficial; os outros 507 não entram. Nenhum registro de consentimento é fabricado.
- Frontend: 206 testes aprovados em 26 arquivos; São Paulo sem seletor, conversão de 09h local para 12h UTC, preservação de fuso/instante de campanha antiga, ausência de Cadastro Mestre/consentimentos e gráfico nos dois temas.
- Navegador local com APIs simuladas: painel claro e escuro inspecionados; textos/legendas legíveis; Disparos inicia sem aba de consentimentos; assistente avança de Público para Configurações, mostra São Paulo sem seletor nem filtro do Cadastro Mestre; Usar lista abre a lista correta no assistente, sem outra etapa. Nenhuma campanha ou teste real foi enviado.
- Texto de ajuda em tema claro conferido no DOM: `rgb(96, 100, 108)` em 14px, substituindo o cinza mais fraco. O gráfico usa rótulos escuros no claro e claros no escuro.
- ESLint: zero erros e 48 avisos; Vite em modo test concluído em 2m15s. Hooks normais de lint-staged/RuboCop executados no checkpoint, sem bypass; avisos legados de lint permanecem.

## Preservação e limites

Sem mudanças em Docker Compose, workflows ou migrations. Banco dedicado de QA: `jrc_campaign_direct_20261126_test`; Redis isolado. Nenhum dado real ou configuração produtiva foi consultado/alterado. Fuso e filtros de campanhas anteriores são preservados; somente novas campanhas adotam São Paulo automaticamente.

Este checkpoint é local. CI remota, publicação GHCR e deploy não executados neste incremento. As imagens publicadas anteriormente permanecem preservadas. [ADR 0007](../adr/0007-campanhas-fluxo-direto-e-legibilidade.md).

## Homologação remota e publicação autorizada

O usuário autorizou push, CI completa e publicação pelo workflow existente, sem deploy. A primeira execução 45819834554 no SHA 34fb7894 executou 1770 exemplos: uma falha de expectativa antiga no teste de rascunho NICO e 60 pendências já existentes. A imagem não foi gerada/publicada. O teste passou a conferir o único telefone elegível, ausência de consentimentos fabricados e todas as proteções de rascunho sem disparo; nenhum código de produção foi alterado nessa correção. A CI completa será repetida no novo checkpoint antes de publicar.

Regressão NICO local após ajuste: 17 exemplos, zero falhas; sem envio externo.
