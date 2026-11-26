# GoPure — Listas salvas na importação CSV

Base: `cb883bb9a0560b509c7278ed0d698265b6acb06f`.
Branch: `codex/gopure-campanhas-listas-csv-20261126`.

## Implementado

O mesmo seletor de listas sanitizadas foi movido para junto das origens, antes do upload, e fica visível no modo CSV e na seleção de lista salva. Usa todas as listas fornecidas no metadata da conta e as recém-criadas no assistente. O backend metadata já fornece todas, sem paginação/truncamento; não foi alterado.

A lista selecionada permanece como sanitized_list_id no payload e na prévia. Selecionar lista existente não cria/importa outra lista. Upload de arquivo novo e digitação manual continuam disponíveis. Não reunir listas nem ampliar o público automaticamente; troca de lista limpa chaves de destinatários da origem anterior para não reutilizar seleção incompatível.

## Verificações

- Oito testes focados de entrada de público aprovados. A nova regressão disponibiliza 25 listas, seleciona uma pelo controle real, confere ID na prévia e no payload, preserva mensagem e prova ausência de chamada de criação de lista. Troca de lista limpa seleção anterior. Sem listas, controle desabilitado e upload disponível.
- Suíte frontend: 219 testes aprovados em 27 arquivos. Depois da checagem adicional de retorno à opção Importar novo CSV, os oito testes focados passaram novamente. Lint sem erros, 35 avisos de regras existentes. Build Vite test final aprovado em 3m30s; hooks normais lint-staged sem bypass.
- Nenhuma alteração de backend/migration, instalação de dados, acesso produtivo ou envio real. Nenhuma CI remota, publicação de imagem ou deploy neste incremento. A base preserva as correções anteriores, inclusive a tradução de erros ainda local.

[ADR 0011](../adr/0011-campanhas-listas-na-importacao-csv.md).

A seleção é exclusiva: escolher lista salva recolhe/descarta o upload pendente; selecionar Importar novo CSV limpa o ID anterior e exige validar o arquivo novo antes de avançar. A mesma seleção guia a prévia.
