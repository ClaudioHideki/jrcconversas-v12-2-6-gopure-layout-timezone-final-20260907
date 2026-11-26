# ADR 0011 — Listas sanitizadas na importação CSV

Estado: implementação local em 26/11/2026.

## Decisão

Exibir o seletor existente de listas sanitizadas diretamente na origem Importar CSV, antes do upload. Usar a coleção audienceLists existente (metadata da conta e listas criadas no assistente, sem duplicar IDs), sem limite adicional nem novo endpoint. Manter a alternativa de importar um novo arquivo e o fluxo manual de números.

A escolha de lista salva alimenta o mesmo sanitized_list_id da campanha e passa pela prévia/validação existentes. Não reimportar/criar cópia e não combinar automaticamente todas as listas. Trocar a lista reinicia a seleção de destinatários da origem anterior, conforme ADR 0006. Preservar nome e mensagens configuradas, bloqueios, isolamento e aprovação do público.

## Evidências e limites

[QA local](../qa/gopure-campanhas-listas-csv-20261126.md). Alteração somente de interface; o endpoint metadata já entrega todas as listas da respectiva conta. Sem mudança em backend, dados, migrations, publicação ou deploy neste incremento.

A seleção é exclusiva: escolher lista salva recolhe/descarta o upload pendente; selecionar Importar novo CSV limpa o ID anterior e exige validar o arquivo novo antes de avançar. A mesma seleção guia a prévia.
