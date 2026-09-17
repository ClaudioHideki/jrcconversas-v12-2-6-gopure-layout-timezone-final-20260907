# GoPure — Contatos, Leads e paginação — 17/09/2026

A Central de Relacionamentos passa a usar o mesmo formulário de criação do CRM. Um contato selecionado mantém seu ID; um Lead manual localiza ou cria o Contact e salva os dois na mesma transação. Contatos que já possuem Lead oferecem acesso ao vínculo existente, respeitando a visibilidade por responsável.

## Arquivos e alterações

| Arquivo | Alteração |
| --- | --- |
| `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue` | Novo Lead no cabeçalho, ação do contato, atualização reativa e paginação/busca. |
| `app/javascript/dashboard/routes/dashboard/contacts/components/ContactLeadAction.vue` | Consulta do vínculo, Criar Lead/Ver Lead, permissões e tentativa após erro. |
| `app/javascript/dashboard/routes/dashboard/crm/views/leads/LeadCreateModal.vue` | Formulário compartilhado, pré-preenchimento, proteção contra clique duplo e erros sem perder dados. |
| `app/javascript/dashboard/routes/dashboard/crm/views/leads/LeadsIndex.vue` | Reutilização do formulário compartilhado. |
| `app/javascript/dashboard/api/crm/leads.js` | Consulta do Lead de um contato. |
| `app/javascript/dashboard/i18n/locale/en/crm.json` | Textos das ações e do formulário, seguindo o catálogo do CRM existente. |
| `app/controllers/api/v1/accounts/crm/leads_controller.rb` | Criação transacional e consulta segura por contato. |
| `app/services/jrc_crm/lead_creation_service.rb` | Reutilização dos identificadores existentes, normalização de telefone e serialização da criação por conta. |
| `app/controllers/api/v1/accounts/contacts_controller.rb` | Desempate por ID na ordenação para evitar registros repetidos ou omitidos entre páginas. |
| `config/routes.rb` | Rota de consulta por contato. |
| `.github/workflows/build-ghcr.yml` | Nova tag de imagem. |
| Cinco novos arquivos de testes em `spec/requests/api/v1/accounts/` e junto às três telas/componentes Vue | Cobertura da integração, paginação e permissões. |

## APIs

- Existente: `POST /api/v1/accounts/:account_id/crm/leads`. Retorna 201 ao criar; 200 ao reutilizar um Lead visível. Um Lead de outro responsável retorna conflito sem expor seu ID ou conteúdo. `owner_id` continua reservado ao administrador.
- Nova: `GET /api/v1/accounts/:account_id/crm/leads/for_contact?contact_id=:id`. Retorna `linked` e o ID apenas se o usuário puder ver o Lead.
- Mantidas: listagem e busca de contatos e conversão do Lead em negócio.

## Banco e regras

Nenhuma migration. Reutilizados `jrc_crm_leads.contact_id`, `Contact`, os mecanismos de busca do importador e o normalizador de telefone existente. Não há alteração de dados de produção nem preenchimento retroativo dos Leads antigos sem contato.

No cadastro manual, informar e-mail, telefone com código do país ou identificador pela API. Identidades que apontem para pessoas diferentes são rejeitadas para seleção explícita do contato. Dados de um Contact existente não são sobrescritos pelo formulário comercial. O responsável padrão é o usuário que cria o Lead; o Contact atual não possui campo próprio de responsável.

## Validação

- RSpec: 27 exemplos aprovados, incluindo Contact existente, cadastro manual, deduplicação, rollback, isolamento entre contas, permissões e conversão em negócio.
- Vitest: 12 testes aprovados, incluindo formulário compartilhado, erro de API, clique duplo, vínculo existente, resposta atrasada, visibilidade do CRM e botões de paginação/busca.
- Caso de 94 contatos: todas as sete páginas acessíveis, sem repetição, com retorno à primeira página. Busca com 31 resultados validada até a terceira página.
- Concorrência no banco isolado: três envios simultâneos resultaram em um Contact, um Lead e duas reutilizações do mesmo vínculo.
- RuboCop dos arquivos Ruby novos: sem infrações após ajustes. ESLint dos componentes/testes novos: sem erros; cinco avisos de formatação de fechamento de tags no formulário.
- Compilação de produção e publicação executadas pelo workflow do GitHub; conferir o resultado do run associado ao commit da entrega.

## Imagem

Tag desta atualização: `ghcr.io/claudiohideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907:4.16.2-jrc-v12.2.6-gopure-contatos-leads-20260917`.

A publicação da imagem não troca automaticamente a versão do servidor. A instalação deverá usar esta tag tanto no serviço web quanto no worker, conforme a configuração já usada pela GoPure.
