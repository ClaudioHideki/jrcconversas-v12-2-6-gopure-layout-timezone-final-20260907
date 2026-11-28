# ADR 0014 — Colagem de hyperlinks no atendimento

Estado: implementação local em 28/11/2026.

## Contexto

Ao copiar um endereço no formato HTML com título, a colagem em canais cujo schema não possui marca `link` descarta o destino e mantém apenas o título. O atendimento utiliza WootWriter/Editor.vue com schema específico por canal; WhatsApp e Channel::Api não suportam hyperlinks com rótulo.

## Decisão

- Usar o hook `transformPastedHTML` do EditorView somente quando o schema não suporta `link`.
- Em fragmento HTML inerte, substituir âncoras textuais HTTP(S) por seu destino como texto. Validar o endereço sem resserializar: conservar query, parâmetros repetidos/vazios, codificação e fragmento.
- Preservar o pipeline atual em canais com hyperlinks (e-mail, WebWidget e notas privadas), texto simples/colar sem formatação, anexos e imagens vinculadas.
- Não alterar o serializador, assinaturas, envio, transportes, backend ou o módulo de campanhas. Não abrir os destinos colados nem inferir URLs a partir de títulos sem endereço.

## Evidências e limites

[QA local](../qa/gopure-atendimento-colagem-links-20261128.md). Usados apenas endereços fictícios. A correção de colagem não muda a validade da sessão de um carrinho na loja. Sem envio real, publicação ou deploy neste incremento.
