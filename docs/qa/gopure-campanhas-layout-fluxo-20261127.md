# QA local — assistente, validar contatos e relatórios

Data: 27/11/2026. Base: `c0bfec06318ea1a6dccdf77444dc428ef96bea67`.
Branch: `codex/gopure-campanhas-layout-fluxo-20261127`.

## Escopo e preservação

Apenas markup/classes dos componentes CampaignWizard, JrcCampaignsPage e CampaignReport, mais textos do locale fonte. Blocos script dos três componentes idênticos à base, normalizando quebras de linha. Mantidos campos, eventos, condições, payloads, API, consentimentos/recusas, isolamento Meta/Evolution, aprovação, seleção manual e fila. Não removidas listas salvas de Importar CSV, nem nenhuma origem/canal ou mensagem.

## Validação local

- 219 testes existentes aprovados em 27 arquivos (`vitest.campaigns.config.ts`), repetidos com sucesso após os ajustes finais de espaçamento e resumo visual de erros. Nenhuma nova suíte adicionada; testes atuais de listas salvas, seleção manual, revisão, conectores e recibos preservados.
- ESLint dos três Vue: 0 erros e 56 avisos de textos/chaves dinâmicas e confirmação existente.
- Build Vite inicial aprovado em 2m14s e build final aprovado em 2m após os ajustes de cartões e linhas. Mantidos avisos existentes sobre Browserslist, asset de marca e chunks grandes/importações.
- `git diff --check`: aprovado.
- Nenhuma alteração em backend, banco/migrations, Docker, workflow ou configuração de produção.

## Navegador sintético

- Desktop 1440 × 1000: assistente central, resumo lateral, etapas e navegação preservadas.
- Importar CSV: 26 opções (Importar novo CSV e 25 listas validadas), incluindo a última lista; ao selecionar a lista 25 não há upload simultâneo. Nenhuma lista copiada/reescrita.
- Página Relatórios: filtros existentes, indicadores e tabela com métricas reais da fixture, data, status e Ver relatório. Detalhe aberto pela linha de uma campanha concluída.
- Detalhe: seis métricas, status traduzidos, erros por código em português com resumo visual de duas linhas; explicação completa e evidência original preservadas nos detalhes, refresh/exportação e paginação existentes. Avançar abre página 2/2 e desabilita Próxima página.
- Celular 390 × 844: relatório sem extrapolar viewport (tabela rolável no próprio contêiner de 341px); assistente com diálogo 374px e rodapé entre 766–835px dentro do viewport.
- Mudanças de viewport restauradas, aba temporária fechada e servidor de prévia encerrado pelo PID registrado. Somente dados sintéticos; sem aprovar, iniciar, enviar ou excluir. A fixture não possui transporte real.

## Limites

A referência visual tem busca e abas/filtros adicionais; não foram adicionados controles sem suporte nem novos contratos de backend nesta alteração somente visual. Lista de campanhas continua usando os filtros existentes e o detalhe conserva paginação de 50 resultados por solicitação/refresh de 15s. Não há totais inferidos, mascaramento de destinos ou reclassificação de recibos.

Sem CI remota, imagem, publicação ou deploy neste incremento. Logs ignorados em `.codex/qa/`.
