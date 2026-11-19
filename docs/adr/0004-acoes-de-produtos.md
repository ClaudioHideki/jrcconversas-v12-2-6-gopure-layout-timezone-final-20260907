# 0004 — Editar, desativar e excluir produtos

Data: 2026-11-19. Estado: implementado e validado localmente.

## Problema

O formulário de edição chamava `structuredClone` sobre regras documentais reativas do Vuex. Isso dispara `DataCloneError` antes de abrir o formulário. O ícone vermelho existente era de ativação/desativação, sem uma ação de exclusão na lista.

## Decisão

- Copiar os registros planos de regras documentais para o formulário, sem compartilhar o rascunho com o catálogo.
- Preservar ativação/desativação e adicionar um botão de lixeira separado, restrito a administradores e com confirmação identificando o produto.
- Usar o DELETE autenticado existente. Não remover itens de propostas ou negócios: manter os snapshots e o comportamento nativo de desvincular o produto.
- Preservar as proteções de integridade para pedidos, contratos e outros registros. Uma restrição de chave estrangeira retorna HTTP 409 com orientação para desativar, sem expor erro de banco nem contornar vínculos.
- Desativar ações durante a requisição, evitar envio duplicado e atualizar o catálogo após sucesso. Erros de exclusão permanecem visíveis na confirmação.

A preparação da publicação também corrige os erros de lint existentes no importador sem mudar sua ordem sequencial, seu tratamento de falhas por linha nem a busca ordenada de aliases. Esses comportamentos são cobertos pelo teste de importação.

## Limites

Não há mudança de schema, transporte, Docker Compose ou permissões. Os testes usam exclusivamente produtos e documentos sintéticos. Nenhum produto real foi editado ou excluído.

Ver [QA local](../qa/gopure-produtos-acoes-20261119.md).
