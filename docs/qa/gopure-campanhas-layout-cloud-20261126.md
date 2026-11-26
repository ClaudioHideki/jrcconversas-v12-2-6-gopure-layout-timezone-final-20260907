# GoPure — Assistente amplo e ritmo Cloud API

Base preservada: `bd641bd4700609cec74ed95b69df55ab25588c40` (inclui exclusão e correções dos recibos).
Branch: `codex/gopure-campanhas-layout-cloud-20261126`.

## Comportamento

Seleção exclusivamente whatsapp_cloud não mostra intervalo mínimo/máximo e salva zero nos campos existentes. O backend confirma o provedor das caixas reais antes de dispensar a espera por destinatário. Seleção mista ou outros provedores conservam o ritmo. Não aumentar concorrência, contornar recusas Meta ou fabricar estimativa de entrega instantânea. Permanecem os atrasos da sequência, agendamento, janelas, templates, aprovação humana, snapshot de destinatários, isolamento e idempotência.

O assistente e o painel deixam de ter teto de largura. Margens internas de 16/24px substituem as largas áreas vazias; resumo de 20rem em desktop, empilhado em larguras menores. Texto principal/controles de 16px, auxiliares de 14px, títulos maiores e cores de texto fortes. Catálogo/editor/prévia se separam em colunas apenas em telas largas. O campo de comportamento da conversa ocupa a largura do cartão.

## Evidência

- Frontend: 212 testes aprovados, 27 arquivos. Cloud API sem ritmo/estimativa nominal, payload zero, mudança para outro provedor conserva os valores e painel sem max-width. Todos os testes anteriores de seleção, Meta/Evolution e relatórios preservados.
- Navegador em ambiente local com APIs simuladas: assistente Público → Configurações; ausência de ritmo para remetente Cloud, texto explicativo, São Paulo e resumo sem estimativa 5–20s. Em viewport desktop de 1600px, conteúdo medido em 1585px (barra de rolagem), max-width none, padding 24px e parágrafo principal 16px; cartões empilham em largura menor. Override de viewport foi removido ao terminar. Nenhum botão de salvar/aprovar/disparar foi acionado.
- Backend final: 229 exemplos, zero falhas. Seleção exclusiva Cloud API agenda exatamente o público aprovado sem atraso artificial; outro provedor e seleção mista mantêm o intervalo. Nenhuma chamada de disparo ao Graph API no teste de agendamento.
- Build Vite test aprovado em 2m16s; ESLint sem erros, 44 avisos de regras existentes. Hooks normais de lint-staged/RuboCop executados no checkpoint, sem bypass.

## Isolamento e limites

Banco local sintético `jrc_campaign_cloud_20261126_test`, Redis DB 11. Nenhum banco produtivo consultado/modificado, envio real, mutation na Meta, migration nova, Compose/workflow alterado, publicação ou deploy neste incremento.

A documentação Meta confirma capacidade limitada; retirar o intervalo manual não aumenta os limites da conta nem garante entrega simultânea. [Referência Meta](https://developers.facebook.com/docs/whatsapp/cloud-vs-onprem/). [ADR 0009](../adr/0009-campanhas-cloud-ritmo-layout.md).
