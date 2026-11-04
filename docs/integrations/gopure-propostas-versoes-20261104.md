# GoPure — versões e reenvio histórico de propostas — 04/11/2026

## Base e preservação do trabalho anterior

- Repositório: `ClaudioHideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907`.
- Base após fetch e comparação: `origin/codex/gopure-campanhas-texto-imagem-20261104`, SHA `5837c8c6150c5da0dd7609ba32f942cdda78b82f`.
- Imagem já publicada dessa base: `ghcr.io/claudiohideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907:gopure-campanhas-texto-imagem-20261104-r2@sha256:70ac1cf0b97526ac0f0ed0454c04a9b5e772baad8a56dae455b0e7729346d2c5`.
- A revisão da imagem e o sucesso da validação/publicação foram confirmados no run [41851154531](https://github.com/ClaudioHideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907/actions/runs/41851154531). A imagem efetivamente instalada em produção não foi consultada; o usuário confirmou essa linha GoPure + Campanhas como referência.
- A base já inclui `216aa1e0` (aceite digital responsivo), `b61fe858` e `5837c8c6` (testes/correção do envio de imagem e legenda nas campanhas). Esses trabalhos não foram refeitos nem substituídos.
- A branch separada `codex/ura-nativa-hml-20261103`, SHA `5b2264a5b6c6af3dad6f43df66b9287420158cea`, possui integração LAB/Broker e 26 migrations fora dessa linha. A divergência foi apresentada ao usuário, que escolheu GoPure + Campanhas. Essa consolidação HML não foi incorporada silenciosamente.
- Worktree exclusivo: `gopure-propostas-versoes-20261104`; branch `codex/gopure-propostas-versoes-20261104`. Os worktrees anteriores e suas alterações foram preservados.

## Comportamento entregue

### Reenviar proposta

- A ação fica no topo da proposta e no alerta de proposta expirada/encerrada, com escolha entre WhatsApp, e-mail e o seletor de destinatário existente.
- Propostas vigentes continuam usando o fluxo normal, suas validações e aprovações. O envio efetivo permanece responsabilidade da integração e dos workers existentes.
- Propostas históricas usam os mesmos serviços nativos de mensagens, mas anexam os bytes do PDF original, registram `historical_resent` e identificam o documento como sem vigência. Os atributos comerciais, status, datas e vínculo de aceite da proposta anterior não são reescritos.
- O novo link histórico é assinado, limitado à conta e à proposta, válido por sete dias e separado dos tokens de aceite. A página contém apenas consulta/download do PDF; não há endpoint de aceite nessa rota. Tokens de outra conta, outra proposta, outra finalidade ou expirados são recusados.
- O PDF é preservado nos eventos com ActiveStorage. Para envios anteriores à mudança, há recuperação do anexo original da última mensagem da própria proposta/conta. Um PDF anteriormente enviado e indisponível não é reconstruído com os dados atuais: o reenvio informa o problema, mas ainda é possível criar uma nova versão.

### Editar e criar nova versão

- Botão primário com ícone de edição, acima do conteúdo, sem menu intermediário.
- Usa a rota existente de duplicação e abre o editor real com os produtos, quantidades, valores, descontos, frete, pagamentos, mensalidades, observações e validade copiados.
- Cria outra proposta, outros itens, número/token próprios e estado de rascunho. As aprovações e o aceite não são herdados. A validade anterior é copiada para revisão pelo usuário; se estiver vencida, deve ser corrigida no novo rascunho antes do envio.
- A numeração é calculada para a família de versões sob lock da raiz; duplicações paralelas partem do mesmo controle. A versão anterior fica bloqueada para alterações e aceite, preservando PDF, dados e eventos.
- Regras de aprovação comercial, financeira, técnica e alçadas continuam no envio da nova versão.

### Histórico de versões

- Ação ao lado dos botões principais, com versões, status comercial e situação pública, datas, validade, valor, responsável e auditoria de alterações/envios.
- Permite abrir a versão e consultar seu PDF autenticado. Documentos originais ausentes são identificados; não são substituídos por reconstruções.
- A família aproveita os eventos existentes de duplicação. A lista retornada continua limitada à conta, ao proprietário/perfil e à visibilidade organizacional existentes.

## Interface e compatibilidade

- Botões com alvos de pelo menos 44 px, quebra de linha em telas pequenas e tokens do tema atual do CRM.
- Formulários e serviços de envio existentes preservados. A versão anterior é somente leitura; o novo rascunho usa o editor comercial completo.
- Textos PT-BR das ações definidos no catálogo-fonte `en/crm.json`, conforme o AGENTS; o fallback PT-BR foi validado usando os catálogos reais. Catálogos gerados pelo Crowdin não foram alterados.
- Página pública histórica usa Tailwind, identidade documental da conta e preferência de tema do navegador.
- Nenhuma migration, configuração de produção ou alteração no código de campanhas foi necessária. Na preparação da publicação, o workflow existente `build-ghcr.yml` recebeu a execução explícita dos testes de interface de Propostas; a seleção antiga de testes comerciais não incluía esses arquivos. A publicação continua condicionada à validação e ao smoke test da imagem.

## Validação local

- Banco PostgreSQL e Redis descartáveis, rede Docker interna, sem portas públicas, sem worker consumindo mensagens e sem conexão à produção. Reutilizada uma imagem local existente apenas para executar Ruby; nenhuma imagem foi construída/publicada.
- Backend: 82 exemplos, zero falhas, incluindo propostas vigentes, expiradas, aceitas, recusadas, canceladas, nova versão, mensalidades, preços/quantidades, aprovação obrigatória, PDF original, token/link, tenant/proprietário e idempotência do envio ao destinatário escolhido.
- Frontend: 32 testes em quatro arquivos, zero falhas, verificando botões conectados às APIs reais, abertura do novo rascunho, reenvio histórico, histórico/PDF, permissões e preservação do fluxo vigente.
- RuboCop dos seis novos arquivos Ruby: sem infrações. O lint dos arquivos legados alterados também foi executado e aponta métricas/estilo da estrutura existente e sua ampliação; não foi feita uma reestruturação geral de controllers/models/serviço de entrega para zerar essas métricas.
- ESLint dos arquivos JS/Vue alterados: zero erros; 46 avisos, principalmente formatação de templates legados e o `confirm` já existente.
- `git diff --check`: sem erros de whitespace.
- Compilação Vite em modo de teste: aprovada; os avisos restantes são Browserslist desatualizado, um sourcemap ausente de dependência nos testes, imagem de marca resolvida em runtime e chunks grandes. Dependências e configurações de build não foram alteradas para ocultar esses avisos.
- Layout: 24 combinações (320, 390 e 1280 px; claro/escuro; proposta, reenvio, histórico e página pública), sem overflow horizontal, ações principais visíveis e alvos de pelo menos 44 px. A página pública não possui formulário de aceite e segue a preferência de tema do navegador.
- Evidências locais, logs e capturas ficam em `.codex/qa/`, ignorado pelo Git. Os HTMLs da tela vêm do componente Vue real com APIs mockadas; o HTML público histórico foi renderizado pelo Rails real com uma proposta fictícia. Essas capturas não representam dados nem telas da produção.

## Homologação e publicação

- Não houve envio real a WhatsApp/e-mail, contato com provedores, mudança de sessão Evolution ou comprovação de entrega externa. Os testes verificam a criação da mensagem nativa com PDF, destinatário, histórico e contratos das integrações.
- Nenhuma alteração foi aplicada diretamente a propostas ou banco de produção. Os anexos e eventos históricos passam a ser preservados pelo fluxo normal da aplicação quando esta atualização for instalada.
- Em 04/11/2026 o usuário autorizou commit, push exclusivo desta branch e publicação de uma imagem candidata com tag própria. Deploy, alteração do banco de produção e substituição de imagens em uso permanecem fora do escopo.
- A candidata solicitada é `gopure-propostas-versoes-20261104-r1`. A confirmação de publicação exige CI aprovada e verificação do SHA/revision e digest no GHCR; a existência deste documento não declara a imagem publicada antecipadamente.
- Antes de instalar: homologar o envio em uma conta de teste autorizada, com um destinatário controlado. Não usar propostas históricas indisponíveis para simular aceite.

## Arquivos desta entrega

| Camada | Arquivos |
| --- | --- |
| API e rotas | `app/controllers/api/v1/accounts/crm/proposals_controller.rb`, `proposal_items_controller.rb`, `app/controllers/jrc_crm/historical_proposals_controller.rb`, `config/routes.rb` |
| Modelo e serialização | `app/models/jrc_crm/proposal.rb`, `proposal_event.rb`, `app/serializers/jrc_crm/proposal_serializer.rb` |
| Serviços | `app/services/jrc_crm/proposal_delivery_service.rb`, `proposal_public_state.rb`, `proposal_version_history.rb`, `proposal_revision_service.rb`, `proposal_document_archive.rb`, `historical_proposal_link.rb` |
| Página pública | `app/views/jrc_crm/historical_proposals/show.html.erb` |
| Interface CRM | `app/javascript/dashboard/routes/dashboard/crm/views/proposals/ProposalsIndex.vue`, `ProposalVersionActions.vue`, `ProposalRecipientDelivery.vue` |
| Cliente API e textos | `app/javascript/dashboard/api/crm/proposals.js`, `app/javascript/dashboard/i18n/locale/en/crm.json` |
| Testes | `spec/requests/api/v1/accounts/crm/proposal_versions_spec.rb`, `app/javascript/dashboard/routes/dashboard/crm/views/proposals/spec/ProposalsIndex.spec.js`, `ProposalVersionActions.spec.js`, `ProposalRecipientDelivery.spec.js` |
| Registro de entrega | Este documento |
| Validação da publicação | `.github/workflows/build-ghcr.yml`: incluir os testes de interface de Propostas antes do build/publicação |

O commit desta entrega é descendente da base `5837c8c6150c5da0dd7609ba32f942cdda78b82f`, na branch de trabalho. Nenhuma atualização da `main` ou de outra branch faz parte da publicação.
