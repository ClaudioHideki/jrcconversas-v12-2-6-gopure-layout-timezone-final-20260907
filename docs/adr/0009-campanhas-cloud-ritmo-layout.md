# ADR 0009 — Ritmo Cloud API e largura do assistente

Estado: implementação local em 26/11/2026.

## Decisão

- Quando todos os remetentes selecionados forem whatsapp_cloud, ocultar os intervalos manuais e enviar zero nos dois campos existentes do payload. Ao mudar para outro provedor, conservar os valores do formulário e suas restrições já existentes.
- No agendamento do backend, remover o atraso artificial por destinatário somente quando todas as caixas remetentes reais são Channel::Whatsapp com provider whatsapp_cloud. Seleção mista mantém o ritmo configurado. Não confiar em rótulo/flag enviado pelo navegador. Não alterar o limite/concorrência dos workers.
- Todos os destinatários aprovados da Cloud API podem entrar na fila no mesmo início permitido da janela; isso não garante envio/entrega simultâneos nem capacidade ilimitada. Preservar aprovação, snapshot, bloqueios, janela de envio, templates, isolamento dos conectores e interpretação dos erros da Meta. Intervalos/follow-ups entre mensagens da sequência não mudam.
- Manter o ritmo dos demais provedores, incluindo Evolution, Broker e e-mail. A seleção de destinatários não é ampliada.
- Retirar os tetos de largura do módulo/assistente; utilizar a área disponível com padding de 16/24px, resumo lateral de 20rem em telas largas e empilhamento em telas menores. Aumentar títulos, controles e textos auxiliares, reforçando os tokens de texto sem modificar o zoom do navegador.
- Não exibir duração nominal baseada em 5–20s para Cloud API; indicar que depende da fila/capacidade da Meta.

## Referência e limites

[Meta — Cloud API](https://developers.facebook.com/docs/whatsapp/cloud-vs-onprem/): há limites de capacidade; a alteração não promete envio ilimitado e não modifica a conta Meta nem seus limites. Nenhum envio real, deploy ou mudança produtiva foi executado.

[QA local](../qa/gopure-campanhas-layout-cloud-20261126.md). As correções anteriores de exclusão e recibos são preservadas na base bd641bd4.
