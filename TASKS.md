<!-- jrc-operational-init:v1 -->
# Backlog operacional — JRC Conversas GoPure

## Em progresso (WIP)







- [ ] **CAMPANHAS-20261125:** Auditoria e correção de templates, mídia de exemplo, rastreamento Meta, janela IANA, catálogo e consentimentos. Checkpoints A–F registrados; 285 exemplos backend e 192 testes frontend, mais teste adicional de rótulo, aprovados; navegador sintético documentado. CI e candidata sem publicação em andamento. Homologação real depende de autorização específica. Ver [evidências](docs/qa/jrc-campanhas-20261125.md).

Nenhuma execução funcional é iniciada por este bootstrap. As frentes já em andamento permanecem nos planos/checkpoints existentes.

## A fazer (To Do)

- [ ] **DOC-01:** Revisar os termos de [glossary.md](docs/domain/glossary.md) com o responsável pelo domínio.
- [ ] **DOC-02:** Conferir [system-overview.md](docs/architecture/system-overview.md) e as versões com o ambiente efetivo quando houver acesso autorizado.
- [ ] **OPS-01:** Homologar envio de texto e imagem somente com o escopo de teste autorizado da GoPure.
- [ ] **OPS-02:** Reconciliar correções genéricas do LAB2 preservando layout e timezone específicos.

## Concluído (Done)

- [x] **CAMPANHAS-LISTAS-CSV-20261126:** Mostrar todas as listas sanitizadas da conta em Importar CSV e reutilizar a selecionada sem novo upload/cópia. [QA](docs/qa/gopure-campanhas-listas-csv-20261126.md). 219 testes frontend e build aprovados; escolha exclusiva entre lista e arquivo. Sem disparos reais/publicação/deploy.

- [x] **CAMPANHAS-ERROS-PT-20261126:** Traduzir erros de relatório por código confirmado, preservar original em detalhes e isolar consulta histórica por conta/caixa. [QA](docs/qa/gopure-campanhas-erros-pt-20261126.md). 232 testes backend, 217 frontend e build aprovados. Sem envio real, publicação ou deploy.

- [x] **CAMPANHAS-CLOUD-20261126:** Remover ritmo manual Cloud API no formulário e agendamento, mantendo demais provedores; ampliar assistente e legibilidade. [QA](docs/qa/gopure-campanhas-layout-cloud-20261126.md). 229 testes backend, 212 frontend, navegador sintético e build aprovados. Sem disparos reais/publicação/deploy.

- [x] **CAMPANHAS-STATUS-20261126:** Excluir campanhas pela coluna do nome; status em português; atualização do relatório; impedir regressão de leitura entre etapas. 226 testes backend, 211 frontend e build aprovados. Sem envios reais, publicação ou deploy. [QA](docs/qa/gopure-campanhas-exclusao-status-20261126.md).

- [x] **CAMPANHAS-FLUXO-20261126:** Simplificar navegação, retirar cadastro prévio obrigatório e filtro do Cadastro Mestre, fixar São Paulo em novas campanhas e reforçar contraste. 217 testes backend, 206 frontend, build e navegador sintético validados; checkpoint local com hooks normais. Sem disparos reais ou deploy. [QA](docs/qa/gopure-campanhas-fluxo-direto-20261126.md).

- [x] **CAMPANHAS-PUBLICO-20261125:** Corrigida perda da seleção manual na primeira criação; base sintética de 511 preserva exatamente quatro na revisão, fila e transporte simulado. 211 exemplos backend, 202 testes frontend e build Vite aprovados localmente. Publicação/CI remota não executadas neste incremento. Sem envios reais ou deploy. [Evidências](docs/qa/jrc-campanhas-publico-manual-20261125.md).

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
