# QA local — layout de disparos e aprovação

Data: 27/11/2026. Base: `543937c6ffd8532e478a833198f0efded28ebe67`.
Branch: `codex/gopure-campanhas-layout-disparos-20261127`.

## Escopo

Somente interface do painel de disparos, menu de ações por campanha e apresentação da revisão/aprovação. Todas as regras e handlers já validados foram preservados. Template/mídia exibidos a partir do snapshot existente; não se buscou nova definição externa nem alterou o conteúdo do envio.

## Verificações

- Suíte existente `vitest.campaigns.config.ts`: **219 testes aprovados em 27 arquivos**. Inclui seleção manual, confirmação de público, listas salvas, revisão, envio separado da aprovação, bloqueio por divergência e isolamento Meta/Evolution.
- Adaptado o teste existente da página para o menu visual VDropdown e a exclusão na mesma linha da campanha; nenhuma nova suíte adicionada.
- ESLint dos cinco arquivos Vue/JS alterados: **0 erros, 20 avisos**, sobre textos/símbolos, chaves dinâmicas de tradução e confirmação existente.
- Build Vite do frontend (`--mode test`): **aprovado em 2m07s**. Avisos existentes de Browserslist, tamanho/importação de chunks e asset de marca não resolvido no build permanecem; nenhuma falha de compilação.
- `git diff --check`: aprovado.
- Nenhuma diferença em backend, modelos, banco/migrations, Docker ou workflows.

## Conferência no navegador com dados sintéticos

- Painel em 1440 × 1000: cinco indicadores com taxas, funil em cores distintas, tabela sem extrapolar o contêiner (1027px disponíveis; tabela 1027px).
- Menu de rascunho: revisar, iniciar, editar, relatório, duplicar e excluir; menu em posição visível no viewport. Escape fecha e retorna ao botão.
- Menu de campanha em execução: pausar, cancelar, editar desabilitado, relatório, duplicar e excluir desabilitado.
- Revisão: dias Seg–Sex, 08:00–18:00, timezone, recorrência Uma vez, distribuição Rodízio e modo de conversa legível. Mensagem e imagem sintéticas, quatro destinatários, parâmetros JSON recolhidos.
- Aprovação desabilitada antes de marcar a confirmação e habilitada depois. Não clicado em aprovar/iniciar/enviar/excluir na prévia.
- Celular em 390 × 844: página com 390px de largura, tabela rolável dentro de 341px; revisão com 366px sem overflow horizontal. Rodapé permanece no viewport (619–832px).
- Tema escuro conferido no painel. Overrides de viewport restaurados, aba temporária fechada e servidor de prévia encerrado pelo PID registrado.
- Primeira navegação local teve timeout de ferramenta; a recuperação pela API DOM do mesmo navegador carregou a prévia. A fixture precisou carregar a folha de estilo de floating-vue usada pelo entrypoint real; não houve mudança no estilo global do produto.

## Limites

Dados e mídias sintéticos; nenhum contato real, API de provedor, disparo real, alteração de banco ou ambiente de produção. Sem CI remota, publicação GHCR ou deploy neste incremento. Os logs locais ficam em `.codex/qa/`, ignorados pelo Git.
