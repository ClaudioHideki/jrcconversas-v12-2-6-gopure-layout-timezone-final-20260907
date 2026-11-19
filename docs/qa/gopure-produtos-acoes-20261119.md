# GoPure — Correção das ações de produtos

Data: 2026-11-19. Branch local: `codex/gopure-produtos-acoes-20261119`.
Base publicada preservada: `0bf4e267da5f82acb890af93d13369174b9a3de9`.

## Implementação

A edição falhava por clonagem de proxies do Vuex. A cópia dos registros planos agora permite abrir o formulário, modificar regras sem alterar o catálogo antes de salvar e persistir os valores pela API existente.

O ícone de ativação/desativação foi mantido. Uma lixeira separada abre confirmação e chama DELETE somente após confirmar. Cancelar não envia requisição. Ações ficam bloqueadas durante o envio e mensagens de erro são mantidas visíveis. Vínculos protegidos retornam 409; pedidos e contratos não são removidos. Os itens de propostas mantêm os valores históricos quando o vínculo opcional com um produto é removido pelo comportamento nativo.

## Verificação

- Reproduzido `DataCloneError` com um catálogo reativo real e comprovada a correção.
- Frontend: a regressão comercial e os sete cenários de ações/importação foram verificados com Vuex e DOM da tela. A preparação da publicação repete a suíte completa e registra os resultados na CI.
- Backend: 25 exemplos aprovados, incluindo atualização, exclusão permanente de produto sintético sem vínculos, snapshots de proposta, rollback por vínculo de pedido, ativação, permissão de agente e isolamento entre contas.
- As primeiras falhas de fixtures foram corrigidas usando o construtor nativo de propostas e tradução explícita no teste; a repetição final passou sem falhas.
- Build Vite de produção completo aprovado: 5.517 módulos, concluído em 2 min 17 s. Avisos existentes de Browserslist, chunks grandes e imagem de marca resolvida em runtime, sem erro de compilação.
- Preparação da publicação: os quatro erros restantes de lint foram corrigidos sem desativar regras. A busca de aliases mantém a ordem, a importação CSV continua sequencial e trata falhas por linha, e a condição da tabela foi separada do laço. O teste de CSV verifica essa preservação.

## Escopo operacional

Foi usado um banco novo e sintético, com fila Redis isolada. Nenhum dado de produção, produto real, pedido ou contrato real foi alterado. O usuário autorizou posteriormente commit, push, CI completa e publicação de nova imagem após aprovação. Esses resultados serão registrados no comprovante final com SHA, tag e digest. Deploy, migrations de produção e alterações em Docker Compose continuam fora do escopo.

Os ajustes anteriores de CRM, cadastro de empresas, propostas e a imagem publicada permanecem preservados.
