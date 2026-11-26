<!-- jrc-operational-init:v1 -->
# Roadmap operacional — JRC Conversas GoPure

Referência inicial: INIT solicitado pelo usuário em 2026-11-13. É uma trilha documental Brownfield, não uma declaração de conclusão do produto.

## Fase 1: Fundação e alinhamento de contexto

- [x] Identificar o projeto e preservar as regras existentes em AGENTS.md.
- [x] Organizar o domínio em docs/domain/ e a arquitetura em docs/architecture/.
- [x] Configurar o pipeline documental de tarefas em TASKS.md e o registro ADR.
- [ ] Revisar os mapas iniciais com os responsáveis do projeto e manter as fontes atualizadas.

## Fase 2: Operação e desenvolvimento ativo

- [ ] Homologar envio de texto e imagem somente com o escopo de teste autorizado da GoPure.
- [ ] Reconciliar correções genéricas do LAB2 preservando layout e timezone específicos.
- [ ] Registrar critério de aceite, teste pertinente e evidência de cada alteração funcional autorizada.

## Fase 3: Estabilização e manutenção

- Correção crítica de público manual de campanhas: separar remetente de origem e confirmar a seleção na aprovação/execução. [ADR 0006](docs/adr/0006-campanhas-selecao-manual-confirmada.md).

- [ ] Documentar casos de borda comprovados e dependências operacionais.
- [ ] Otimizar rotinas repetitivas somente após medir a necessidade.
- [ ] Revisar proveniência, isolamento e versões a cada candidata de release.

Veja [TASKS.md](TASKS.md). Roadmaps e planos anteriores continuam válidos no seu escopo.

## Incremento 2026-11-25 — JRC Campanhas

Templates oficiais com mídias retidas por conta, exemplos automáticos, idempotência e rastreamento de testes Meta, fuso IANA e consistência de público/consentimentos. Evolução genérica, sem dados fixos da GoPure. Candidata de CI não representa homologação externa, publicação ou deploy. Ver [ADR 0005](docs/adr/0005-campanhas-meta-midia-timezone.md).

## Incremento de atendimento — 2026-11-16

Respostas rápidas com anexos e contexto adicionadas à trilha de evolução. Implementação e testes locais têm evidências próprias; CI, build completo, publicação e aceite com provedores continuam sendo etapas separadas. Referência: [ADR 0002](docs/adr/0002-respostas-rapidas-contextuais.md).

## Incremento 2026-11-19 — Cadastro e envio no CRM

- [x] Validar cadastro completo de endereço, solicitação única de aprovação e diálogo compacto de envio, preservando canais e histórico nativos.

Evidências locais deste incremento: [QA CRM simplificado](docs/qa/gopure-crm-simplificado-20261119.md).

## Incremento 2026-11-19 — Ações de produtos

- [x] Corrigir edição reativa, exclusão confirmada e mensagens de vínculos protegidos. [Evidências locais](docs/qa/gopure-produtos-acoes-20261119.md).
