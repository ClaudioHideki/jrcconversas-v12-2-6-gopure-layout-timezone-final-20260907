# CRM comercial — implementação e validação — 22/09/2026

Base auditada: `cdea922`, repositório GoPure existente. O checkout de origem estava limpo antes do início. Trabalho isolado na branch `codex/crm-commercial-complete-20260922`, sem modificar bancos ou volumes reais.

## Entrega funcional

| Item solicitado | Resultado |
|---|---|
| 1. Diagnóstico | Abas de contatos filtravam apenas a apresentação; seletor de pedidos dependia de uma página; financeiro confundia cobrança única/recorrência; implantação era tratada como geral; classes de cores inexistentes no Tailwind deixavam ações transparentes. |
| 2. Reutilização | Contact, Company/labels, Product, SalesOrder/OrderItem, Activity/ActivityDispatchService, BackofficeRequest, Proposal, Pipeline/Stage, policies e componentes do CRM foram preservados. |
| 3. Arquivos | Inventário completo ao final. Nenhuma dependência adicionada/atualizada. |
| 4. Migration | `20260922160000_extend_commercial_order_activities`: vínculo opcional Activity → SalesOrder, índice/FK; prazo contratual do produto passa a aceitar vazio, sem preencher ou reclassificar produtos antigos. Rollback recusa perda de vínculos ou invenção de prazos. |
| 5. Models | Validações de conta/relacionamentos, quantidades/valores e implantação; remoção de funis/etapas em uso protegida. |
| 6. Services | OrderFinancials centraliza valores; ProposalToOrderService normaliza itens sem alterar propostas antigas; OrderWorkflowSync reutiliza atividades/backoffice; OrderPdfService pagina todos os itens. |
| 7. API | Contatos recebem filtros antes da paginação; pedidos usam cálculo confiável no preview/create/update; atividades aceitam sales_order_id; stages/reorder valida IDs, posições e conta. |
| 8. Frontend | ContactPicker com pesquisa global/paginação; wizard condicional; edição financeira; próximos passos; atalhos Negócio → Proposta/Pedido/Atividades. |
| 9. Produtos | Mantidos billing_model, product_type, sales_unit, unit_price_cents, setup_fee_cents e integrations. requires_implementation reutiliza integrations. Cadastro administrativo acessível a partir do pedido. |
| 10. Quantidade | Positiva, decimal com até três casas conforme coluna existente. Quantidades grandes sem limite artificial novo. API rejeita precisão que o banco perderia. |
| 11. Implantação | Independente da recorrência. Somente itens marcados exigem responsável/data e entram no backoffice; venda direta dispensa etapa/checklist/técnico. |
| 12. Recorrência | one_time, monthly, annual e usage existentes preservados; anual normalizado para MRR. |
| 13. Valor inicial | Itens únicos + ativações unitárias × quantidade − desconto geral + frete + impostos + acréscimos. Impostos incidem no inicial líquido mais frete. |
| 14. MRR | Recorrência calculada por quantidade, separada do inicial. Item explicitamente one_time nunca herda MRR antigo da proposta. |
| 15. Contrato | Soma recorrência × prazo por item apenas quando todos os itens recorrentes têm prazo conhecido. Sem prazo, não inventa 12 meses. Contrato global = inicial + recorrência contratada. |
| 16. Contatos | Pessoas/Empresas por vínculo/campo de empresa; Grupos por etiquetas existentes; Sem responsável por dono CRM; Duplicados somente identifica candidatos, não mescla. Busca inclui telefone, e-mail, nome e empresa, na conta autorizada. |
| 17. Wizard | Rodapé separado da área rolável; Anterior/Avançar/Finalizar; mensagens de impedimento; salvar aguarda preview válido; bloqueio de envio duplicado; data local enviada com fuso. |
| 18. Próximos passos | Criar, editar e concluir Activity no pedido, com data, responsável, tipo e descrição; integração existente com agenda reutilizada. |
| 19. Funis/Etapas | Entrada administrativa no funil; CRUD existente reutilizado; subir/descer etapas persiste ordem; movimentação dos cards preservada; exclusão em uso recusada. |
| 20. Permissões | Agente usa catálogo e opera pedidos/atividades permitidos; produto/funil administrativos continuam protegidos no backend. Não foi criada autorização implícita nova para agentes. |
| 21. Multitenancy | Consultas e associações validadas por account e escopo do usuário, inclusive cliente, produto, negócio, proposta, atividade, pipeline e stage. |
| 22. E-mail | Mantido indisponível com mensagem humana e comunicação_available=false. Infraestrutura de mensagens/ActivityDispatch não equivale a envio comercial do pedido; nenhum sucesso fictício ou SMTP inventado. |
| 23. UX/rolagem | Tema CRM por account; GoPure usa verde, outros tenants preservam identidade; cores usam tokens existentes/valores estáticos compiláveis. CRM tem área de rolagem por tela, abas horizontais e ações do wizard fixas. |
| 24. Novos testes | OrderFinancials, commercial_complete, commercial_documents e commercial.spec.js: cenários financeiros A–E, persistência, PDF, escopo, filtros, permissões, wizard, identidade de contatos e tema. |
| 25. Execução | Resultados e comandos abaixo. Tudo executado com dados sintéticos em PostgreSQL descartável e RAILS_ENV=test. |
| 26. Resultado | Implementação validada nas suítes locais; não equivale a deploy em produção. |
| 27. Regressões | Contato → Lead, proposta → pedido, atividades, policies, roteamento, templates WhatsApp/24h e NICO verificados. |
| 28. NICO | Contratos de execução, consulta CRM, deduplicação, confirmação, delegação, movimentação, isolamento e negação de ações indevidas testados em fixture/mocks; runtime sem alteração. Ver ressalvas abaixo. |
| 29. Dependências externas | Bateria conversacional com provedor real, telefonia/ERP e entregas externas depende do ambiente/credenciais e dados de homologação correspondentes. Não executada com tokens reais. Envio comercial de e-mail permanece indisponível conforme especificação. |
| 30. Migration/deploy | Comandos abaixo. Nenhum banco foi resetado, nenhuma imagem anterior foi removida. |

## Evidências e testes

- Rails CRM/NICO/contatos/policies: **179 exemplos, 0 falhas**. Inclui 95 exemplos de NICO.
- Frontend CRM/NICO/contatos: **130 testes, 0 falhas**, em 13 arquivos.
- WhatsApp backend: **41 testes, 123 assertions, 0 falhas**.
- WhatsApp frontend + rotas CRM: **67 testes, 0 falhas**.
- NICO runtime: **17 testes, 0 falhas**; provider simulado, contratos HTTP/autorização/conta reais do runtime.
- Regressões adicionais de governança/campanhas/superadmin: **48 exemplos, 0 falhas**. Total consolidado: **482 testes/exemplos aprovados** nas seis baterias.
- Compilação Vite: **concluída com exit code 0**. NODE_OPTIONS de 4 GB também configurado no job de validação do CI.
- RuboCop: **24 arquivos, nenhum problema Lint**; não representa saneamento dos avisos de estilo legados do projeto.
- ESLint: componentes e testes comerciais sem erros; 11 avisos de formatação de tags já identificados. JSON de traduções válido; `git diff --check` limpo; arquivos modificados normalizados para LF.
- PDF gerado e inspecionado: dez itens em quatro páginas, todos visíveis, resumo inicial/MRR separado, descontos/frete/imposto/acréscimo corretos e sem implantação para venda direta.
- Browser local: login sintético; seletor avançou página 1 → 2 entre 94 contatos; busca Pessoa QA 093 encontrou ID 601 fora da primeira página, com telefone correto; pedido direto 100 × R$20 salvo e reaberto por R$2.000/MRR zero; ajustes de R$200 de desconto, R$100 de frete, 10% de imposto e R$5 de acréscimo resultaram em R$2.095 ao reabrir; próximo passo criado com data/responsável.

Os arquivos de evidência `tmp/commercial-rails-final.json`, `tmp/commercial-vitest-final.json`, `tmp/commercial-regressions.json` e `tmp/commercial-order-qa.pdf` são artefatos locais ignorados pelo Git.

## Homologação NICO — alcance da evidência

O relatório fornecido contempla linguagem natural e uma lista extensa de cenários manuais. Não foram marcados todos como aprovados por inferência.

| Grupo da bateria | Evidência automatizada |
|---|---|
| Permissões, carteira, consulta e tenant (A01/A07–A14, ADM20/ADM30) | context_builder, erp_context, history_access, assistance, knowledge, operations e ERP gates. |
| Criação de atividade/reunião e operação CRM (A16 em diante) | commercial_workflow e commercial_delegation: gravação no banco, contato/lead reutilizados, data/fuso, permissão de ferramenta e confirmação. |
| Ações sensíveis e prevenção de execução indevida | operations, notices, runs e delegation: revalidação na execução, account scope, nenhuma ação fora das categorias concedidas, deduplicação, aprovação única e interrupção por humano. |
| Runtime/provedor e contexto | 17 testes do runtime e testes Rails RuntimeClient, com respostas do provedor simuladas; não medem qualidade semântica de um modelo online. |
| Resposta em linguagem natural, áudio real e canais externos | Homologação online pendente no ambiente próprio. Nenhuma credencial foi alterada/usada para simular conclusão desta etapa. |

## Compatibilidade e publicação

Produtos antigos mantêm seus valores e prazos já gravados. O prazo 12 anteriormente existente não foi removido em massa. Itens históricos sem billing_model preservam o tratamento de valores recorrentes legados; itens explicitamente de venda única usam a regra correta. Nenhum recálculo em massa de pedidos antigos foi executado.

O workflow conserva o repositório e publica somente a imagem da aplicação, usada por Rails e Sidekiq. A tag reservada no workflow é `4.16.2-gopure-crm-comercial-20260922-r1`; **não é confirmação de imagem publicada**. O runtime NICO não requer reconstrução por estas mudanças.

Após a revisão/publicação bem-sucedida do workflow, atualizar a mesma tag nos serviços Rails e Sidekiq do compose existente, preservando ambiente, volumes, Postgres, Redis, runtime e domínio. Exemplo (substituir os nomes se forem diferentes no compose real):

```sh
docker compose pull rails sidekiq
docker compose run --rm rails bundle exec rails db:migrate
docker compose up -d rails sidekiq
```

Não executar db:drop, db:reset, schema:load nem down de volumes em ambientes com dados. A migration é incremental. O rollback de schema deliberadamente bloqueia operações que perderiam vínculos ou exigiriam inventar prazos.

## Comandos de verificação

No ambiente Linux com dependências do projeto, PostgreSQL/Redis exclusivos de teste e RAILS_ENV=test:

```sh
bundle exec ruby scripts/nico-specs.rb   spec/requests/api/v1/accounts/crm spec/models/jrc_crm   spec/services/jrc_crm spec/policies/jrc_crm   spec/requests/api/v1/accounts/contacts_pagination_spec.rb   spec/services/jrc_nico spec/jobs/jrc_nico spec/requests/jrc_nico*   spec/services/jrc_ai/nico_readiness_spec.rb   spec/services/jrc_campaigns/governance_spec.rb   spec/requests/api/v1/accounts/jrc_campaigns/governance_spec.rb   spec/controllers/super_admin/accounts_controller_spec.rb
pnpm exec vitest run --config vitest.commercial.config.ts
ruby scripts/qa/whatsapp24h/services_test.rb
node --experimental-vm-modules --test scripts/qa/whatsapp24h/frontend_test.mjs tests/router/crm-routing.test.cjs
NODE_OPTIONS=--max-old-space-size=4096 pnpm exec vite build
cd services/nico-runtime
npm run build
npm test
```

No host Windows, os testes usaram contêineres `crm-complete-qa-*` com banco `crm_complete_test` em tmpfs. Montagens de dependências existentes foram somente leitura. A compilação e os testes de views Rails devem ser sequenciais para não iniciar duas compilações Vite concorrentes na memória limitada do Docker Desktop. Para repetir testes após compilar os assets de teste, definir VITE_RUBY_AUTO_BUILD=false evita reconstrução desnecessária.

## Arquivos desta entrega

- `.github/workflows/build-ghcr.yml`
- `app/controllers/api/v1/accounts/contacts_controller.rb`
- `app/controllers/api/v1/accounts/crm/activities_controller.rb`
- `app/controllers/api/v1/accounts/crm/products_controller.rb`
- `app/controllers/api/v1/accounts/crm/sales_orders_controller.rb`
- `app/controllers/api/v1/accounts/crm/stages_controller.rb`
- `app/javascript/dashboard/api/contacts.js`
- `app/javascript/dashboard/api/crm/stages.js`
- `app/javascript/dashboard/api/specs/contacts.spec.js`
- `app/javascript/dashboard/i18n/locale/en/crm.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/crm.json`
- `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/CrmLayout.vue`
- `app/javascript/dashboard/routes/dashboard/crm/components/kanban/DealsFunnelKanban.vue`
- `app/javascript/dashboard/routes/dashboard/crm/components/shared/ContactPicker.vue`
- `app/javascript/dashboard/routes/dashboard/crm/components/shared/OrderActivities.vue`
- `app/javascript/dashboard/routes/dashboard/crm/components/shared/OrderFinancialEditor.vue`
- `app/javascript/dashboard/routes/dashboard/crm/crmControlClasses.js`
- `app/javascript/dashboard/routes/dashboard/crm/specs/commercial.spec.js`
- `app/javascript/dashboard/routes/dashboard/crm/useCrmTheme.js`
- `app/javascript/dashboard/routes/dashboard/crm/views/activities/ActivitiesIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/automations/AutomationsIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/campaigns/CampaignsCrmIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/contracts/ContractsView.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/deals/DealsIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/leads/LeadConversionModal.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/leads/LeadCreateModal.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/leads/LeadDetailModal.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/orders/SalesOrderWizard.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/orders/SalesOrdersView.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/products/ProductsIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/proposals/ProposalsIndex.vue`
- `app/javascript/dashboard/routes/dashboard/crm/views/settings/CrmSettingsView.vue`
- `app/javascript/dashboard/store/modules/contacts/actions.js`
- `app/javascript/dashboard/store/modules/contacts/mutations.js`
- `app/models/jrc_crm/activity.rb`
- `app/models/jrc_crm/order_item.rb`
- `app/models/jrc_crm/pipeline.rb`
- `app/models/jrc_crm/product.rb`
- `app/models/jrc_crm/sales_order.rb`
- `app/models/jrc_crm/stage.rb`
- `app/serializers/jrc_crm/activity_serializer.rb`
- `app/serializers/jrc_crm/product_serializer.rb`
- `app/serializers/jrc_crm/proposal_serializer.rb`
- `app/services/contacts/relationship_filter.rb`
- `app/services/jrc_crm/order_financials.rb`
- `app/services/jrc_crm/order_pdf_service.rb`
- `app/services/jrc_crm/order_workflow_sync_service.rb`
- `app/services/jrc_crm/proposal_to_order_service.rb`
- `app/views/api/v1/accounts/contacts/active.json.jbuilder`
- `app/views/api/v1/accounts/contacts/filter.json.jbuilder`
- `app/views/api/v1/accounts/contacts/index.json.jbuilder`
- `app/views/api/v1/accounts/contacts/search.json.jbuilder`
- `app/views/api/v1/models/_contact.json.jbuilder`
- `db/migrate/20260922160000_extend_commercial_order_activities.rb`
- `db/schema.rb`
- `spec/requests/api/v1/accounts/crm/commercial_complete_spec.rb`
- `spec/services/jrc_crm/commercial_documents_spec.rb`
- `spec/services/jrc_crm/order_financials_spec.rb`
- `vitest.commercial.config.ts`
