# ADR 0010 — Erros de campanhas em português

Estado: implementação local em 26/11/2026.

## Decisão

- Exibir explicação em português para erros Meta 131049 e 131026, usando o código estruturado confirmado no webhook. Não classificar por texto quando há um código diferente/desconhecido.
- Recuperar o código também para relatórios históricos a partir dos StatusEvents existentes, por inbox/external_id do delivery e conta da campanha. Consulta única em lote por página, sem migrar/reescrever registros.
- Quando não houver código histórico, reconhecer somente os dois títulos legados conhecidos. Outros retornos usam explicação genérica em português, sem inventar causa ou código.
- Preservar error_message original na API/banco e mostrar o original em Detalhes técnicos recolhidos. Acrescentar error_code à resposta do relatório. CSV permanece com a evidência original existente.
- A tradução não libera destinatário, muda status, altera blacklist, cria consentimento nem reenvia mensagens. As restrições da Meta e os demais conectores não mudam.

## Referência e limites

[Documentação Meta de códigos](https://developers.facebook.com/documentation/business-messaging/whatsapp/support/error-codes): para 131049, aguardar pelo menos 24 horas antes de tentar novamente, sem garantia; 131026 não identifica uma causa específica só pelo título. Os códigos dos casos informados foram confirmados pelo usuário mediante consulta somente de leitura no Dokploy; nenhum dado privado desse retorno foi incluído no repositório.

[QA local](../qa/gopure-campanhas-erros-pt-20261126.md). Sem envio real, publicação ou deploy neste incremento.
