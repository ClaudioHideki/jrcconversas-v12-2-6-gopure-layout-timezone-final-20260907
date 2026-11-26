# ADR 0008 — Exclusão visível e recibos de leitura

Estado: implementação local em 26/11/2026.

## Decisão

- Exibir Excluir junto ao nome da campanha, independente da rolagem horizontal das métricas. Confirmar a remoção definitiva de campanha e histórico. Não excluir mensagens, contatos, consentimentos ou mídias da conta. Preservar autorização de administrador, isolamento por conta e bloqueio de exclusão em execução/pausa; conferir o estado sob lock para serializar com lançamento.
- Traduzir os estados de destinatários na interface, preservando os códigos da API. Relatório aberto consulta a mesma página a cada 15 segundos, sem sobrepor requisições; oferece atualização manual, conserva último resultado em falha e encerra o timer ao fechar. Fechar o relatório atualiza os indicadores da página.
- Recibos continuam vindos do provedor. Não inferir leitura por abrir o relatório, entrega, resposta ou relato do operador. A Meta continua exclusivamente na rota oficial existente, sem consulta/fallback Evolution.
- Preservar leitura/resposta agregada do destinatário quando outro passo recebe evento atrasado. Serializar a atualização por destinatário, mesmo que os eventos pertençam a deliveries diferentes. Continuar atualizando eventos de campanhas concluídas.

## Limites

A captura mostra estado Entregue, mas não prova se chegou recibo de leitura desse destinatário. Foram identificados carregamento único do relatório e possível regressão agregada entre etapas. O caso real exige correlação do webhook no servidor; não afirmar que uma leitura não recebida foi recuperada. Nenhum disparo real, edição produtiva, migration, publicação ou deploy neste incremento.

[Evidências locais](../qa/gopure-campanhas-exclusao-status-20261126.md).
