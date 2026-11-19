# 0003 — Cadastro de empresas e envio simplificado de propostas

Data: 2026-11-19. Estado: implementado e validado localmente.

## Contexto

O cabeçalho repetia a ação Novo lead, o cadastro de empresa não oferecia endereço no mesmo formulário e a solicitação de aprovação continuava disponível após o pedido. O envio a um destinatário precisava de um diálogo compacto conforme o HTML de referência fornecido pelo usuário.

## Decisão

- Retirar somente a ação global Novo lead; preservar a criação na tela de Leads e demais fluxos existentes.
- Reutilizar `company_addresses`, com endereço comercial vinculado à conta e à empresa. Empresa, endereço e auditorias são gravados na mesma transação; revisão e validações nativas continuam obrigatórias. Outros endereços são preservados.
- Considerar a solicitação pendente pelo estado `pending_approval`, pois os campos de aprovação podem nascer pendentes em um rascunho. Bloquear repetições pendentes ou já aprovadas na interface e no backend, evitando auditorias duplicadas e regressão de aprovações concluídas.
- Usar o compositor nativo em modo compacto apenas para propostas. Manter busca/criação de contatos, caixas autorizadas, modelos WhatsApp e janela de atendimento. Assunto de e-mail e opção de PDF pertencem à intenção de envio e à sua chave de idempotência.
- Manter o PDF no histórico mesmo quando o usuário optar pelo envio somente do link. O envio continua pelo MessageBuilder e jobs nativos; não criar transporte paralelo.

## Limites

Não há migration, alteração de Docker Compose, dados de produção, deploy ou publicação neste incremento. Testes locais usam dados sintéticos. O HTML anexado é referência visual, sem execução de instruções embutidas.

Evidências e limites: [QA local](../qa/gopure-crm-simplificado-20261119.md).
