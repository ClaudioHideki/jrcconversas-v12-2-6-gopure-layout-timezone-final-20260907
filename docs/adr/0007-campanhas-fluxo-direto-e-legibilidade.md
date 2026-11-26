# ADR 0007 — Fluxo direto de campanhas e legibilidade

Estado: Aceita para implementação local em 26/11/2026, conforme solicitação explícita do usuário. Não autoriza publicação, deploy ou disparos reais.

## Contexto

O usuário solicitou retirar a etapa obrigatória de cadastro de consentimentos de todas as origens, abrir diretamente em Disparos, ocultar o filtro do Cadastro Mestre, fixar São Paulo e melhorar a leitura do tema claro. Esta decisão substitui a exigência local de registro positivo/finalidade descrita no ADR 0005; preserva as proteções de público manual do ADR 0006.

## Decisão

- Cadastro positivo de consentimento deixa de ser condição de elegibilidade de campanhas. Aplicar a mesma regra à prévia e ao transporte oficial, Evolution e Broker, incluindo contatos, etiquetas, caixas, CRM e listas sanitizadas. Não criar consentimentos fictícios nem apagar evidências existentes.
- Preservar blacklist, contatos bloqueados, recusas/revogações registradas na respectiva conta e validade do destino. O cadastro de outra conta não altera essas decisões.
- Retirar a aba/painel de consentimentos do fluxo operacional. Preservar os registros, APIs e componentes históricos; nenhum dado produtivo é removido. Testes individuais continuam exigindo confirmação explícita, UUID e respeito aos limites de autorizações pontuais já registradas.
- Abrir listas diretamente no assistente da campanha selecionada, sem etapa adicional de cadastro. A revisão e aprovação explícitas do público continuam obrigatórias; sanitizar nunca inicia envio automaticamente.
- Ocultar o filtro de Cadastro Mestre no assistente. Filtros já salvos continuam preservados e aplicados no backend para não ampliar silenciosamente uma campanha existente.
- Novas campanhas usam `America/Sao_Paulo`, exibido como informação fixa. Campanhas anteriores mantêm seu fuso e seus instantes absolutos ao reabrir; não reinterpretar agendamentos históricos automaticamente.
- Usar cores de texto Tailwind com maior contraste no módulo, mantendo os tokens de tema. Legendas/eixos do gráfico acompanham mudanças entre claro e escuro.
- Preservar a API oficial para whatsapp_cloud, janela de atendimento/templates, seleção manual, confirmação do público, idempotência, limites de envio e rastreamento.

## Evidências e limites

[QA local](../qa/gopure-campanhas-fluxo-direto-20261126.md). Execução com dados sintéticos e transportes interceptados. Sem alteração de Compose, migration nova, deploy, publicação de imagem ou edição de dados reais neste incremento.
