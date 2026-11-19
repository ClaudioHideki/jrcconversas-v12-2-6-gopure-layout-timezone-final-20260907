<!-- jrc-operational-init:v1 -->
# Backlog operacional — JRC Conversas GoPure

## Em progresso (WIP)

Nenhuma execução funcional é iniciada por este bootstrap. As frentes já em andamento permanecem nos planos/checkpoints existentes.

## A fazer (To Do)

- [ ] **DOC-01:** Revisar os termos de [glossary.md](docs/domain/glossary.md) com o responsável pelo domínio.
- [ ] **DOC-02:** Conferir [system-overview.md](docs/architecture/system-overview.md) e as versões com o ambiente efetivo quando houver acesso autorizado.
- [ ] **OPS-01:** Homologar envio de texto e imagem somente com o escopo de teste autorizado da GoPure.
- [ ] **OPS-02:** Reconciliar correções genéricas do LAB2 preservando layout e timezone específicos.

## Concluído (Done)

- [x] **CRM-PRODUTOS-20261119:** Corrigir edição de catálogo e oferecer exclusão confirmada, preservando ativação e vínculos. Ver [QA local](docs/qa/gopure-produtos-acoes-20261119.md).

- [x] **CRM-20261119:** Remover ação global duplicada, incluir endereço completo da empresa, bloquear aprovação já solicitada e simplificar envio de propostas; validado somente com dados sintéticos. Ver [QA local](docs/qa/gopure-crm-simplificado-20261119.md); publicação não executada.

- [x] **BOOTSTRAP-01:** Identidade, stack, natureza Brownfield e fontes locais registradas.
- [x] **BOOTSTRAP-02:** Estrutura INIT, domínio, arquitetura e ADR organizados sem apagar conteúdo anterior.

## Como manter

Uma tarefa deve registrar problema, escopo, critério de aceite, evidência/arquivo e limite. Só mover para Concluído com a prova correspondente; não converter publicação de imagem em aceite operacional.

## Incremento 2026-11-16 — Respostas rápidas

- [x] Arquitetura e referência funcional conferidas; base publicada preservada.
- [x] Catálogo com um anexo, aliases contextuais, revisão e confirmação de envio implementados localmente.
- [x] Isolamento, revisão de arquivos e idempotência persistente cobertos por testes locais.
- [x] Validar interface real com backend e dados sintéticos: 23 verificações, incluindo temas, celular, CRUD, `/`, inserção e repetição após perda de resposta HTTP.
- [ ] Executar build de produção e CI completa em ambiente com recursos suficientes, antes de qualquer publicação.
- [ ] Obter autorização específica para push e publicação deste incremento; não realizar deploy automático.

A implementação, testes locais e limitações estão registrados em [docs/qa/gopure-respostas-rapidas-20261116.md](docs/qa/gopure-respostas-rapidas-20261116.md). Sem autorização de publicação ou deploy para este incremento.
