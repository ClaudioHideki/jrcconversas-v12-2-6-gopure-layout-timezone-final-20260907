# ADR 0013 — Apresentação do assistente e dos relatórios

Estado: implementação local em 27/11/2026.

## Decisão

Continuar o layout aprovado no ADR 0012, sem alterar regras de campanhas. Apresentar o assistente em diálogo central com resumo lateral no desktop e controles de navegação fixos. Preservar todos os inputs, eventos, condições, seleção manual e a escolha exclusiva entre CSV novo e todas as listas salvas da conta.

Trocar os rótulos de Sanitizar Lista/Sanitizar por Validar contatos/Validar e listas sanitizadas por listas validadas. Manter chaves de tradução, nomes de componentes, API e termos internos para evitar alteração de contratos.

Reorganizar a página de relatórios em filtros já disponíveis, indicadores coloridos e tabela com métricas existentes por campanha. O botão Ver relatório abre o mesmo relatório. Não introduzir busca, abas ou filtros de destinatário ilustrativos da referência sem suporte no fluxo existente.

Apresentar o relatório lateral com nome e status da campanha, métricas, informação de recibos, tabela com badges de status, evidência técnica recolhida e a mesma paginação. Preservar atualização automática de 15s, tradução dos erros e exportação CSV.

## Limites

Somente templates Vue e textos no locale fonte. Blocos script dos três componentes comparados byte a byte (normalizando CRLF) com a base c0bfec06. Nenhuma mudança em payload, resolver, serviço, transporte, filas, aprovação, esquema ou configuração de produção.

[Evidências locais](../qa/gopure-campanhas-layout-fluxo-20261127.md). Sem publicação/deploy ou disparos reais.
