# Refatoracao CRM Geral - 2026-09-18

## Documento normativo
A partir desta versao, `JRC_Conversas_CRM_Geral_Dev_Handoff_20260918.docx` e a referencia funcional/tecnica do CRM. Implementacoes anteriores devem ser interpretadas por esse modelo, preservando compatibilidade e dados.

## Decisoes consolidadas
- `Account` continua sendo o tenant/organizacao raiz nesta base Chatwoot; `JrcCrm::BusinessUnit` representa empresa/unidade comercial. Evita duplicar tenant e permite migracao incremental.
- Todas as novas entidades operacionais aceitam `business_unit_id`; a migracao e aditiva e inicialmente nullable para dados legados.
- Contato e cadastro mestre; relacionamentos comerciais sao filtrados por unidade.
- Lead converte para contato + negocio sem duplicacao. Novo interesse de cliente existente cria novo negocio, nao novo lead.
- Proposta e entidade unica com tipo (proposta/orcamento/cotacao) e deve evoluir por versoes imutaveis.
- Pedido aceita origem `proposal`, `deal` ou `manual`; venda direta nao exige Deal quando configurada.
- Pedido guarda snapshot e itens proprios; contrato guarda itens/servicos proprios.
- Contrato nasce preferencialmente de Pedido aprovado e calcula termino a partir de inicio + vigencia.
- Metas suportam usuario/equipe/unidade/produto; `Meta da equipe` nao deve ser enviada como user_id.
- Comissao passa a poder pertencer a Programa de Comissao e a liberacao deve ser condicionada a evento configuravel.
- Financeiro comercial recebe fundacao de Fatura + Pagamento; pagamento parcial e conciliacao devem ser transacionais na proxima etapa de controllers/services.
- RBAC alvo: resource + action + scope (OWN/TEAM/BUSINESS_UNIT/SELECTED_BUSINESS_UNITS/GROUP). O frontend nunca substitui autorizacao server-side.

## Mudancas desta refatoracao
1. Migration `20260918130000_refactor_jrc_crm_general_architecture.rb`.
2. `business_units` e `user_business_units`.
3. `business_unit_id` aditivo nas principais tabelas CRM existentes.
4. Venda direta: `sales_orders.deal_id` passa a opcional e `source_type` identifica origem.
5. `order_items` e `contract_items` para snapshots comerciais/contratuais.
6. Campos de contrato para pagamento e renovacao.
7. Fundacao de `invoices` e `payments`.
8. `commission_programs` e associacao opcional em comissoes.
9. Metas ganham `scope_kind`, `metric`, produto e quantidade alvo.
10. `start-local.ps1` agora constroi `chatwoot:development` antes das imagens Rails/Vite, corrigindo o erro de pull da imagem inexistente.

## Compatibilidade / ativacao
- Nenhuma tabela legada e removida.
- Nenhum dado e apagado.
- `business_unit_id` permanece nullable nesta primeira migracao para permitir backfill seguro.
- Antes de tornar unidade obrigatoria, criar unidade padrao por Account e fazer backfill auditado.
- Financeiro, programas de comissao e escopos avancados sao fundacao de dados nesta entrega; nao devem ser anunciados como workflow completo ate controllers, policies, UI e E2E passarem nos criterios do handoff.

## Proxima implementacao obrigatoria
1. Policy central por resource/action/scope e filtro server-side de business unit.
2. Backfill de unidade padrao e seletor de contexto apenas para usuarios multiempresa.
3. Cliente 360 filtrado por unidade e permissao.
4. Fechar Proposta -> Pedido -> Contrato sem redigitacao e com idempotencia.
5. Wizard de Pedido com proposta/negocio/manual.
6. Wizard de Contrato com origem/servicos/financeiro/vigencia/documentos/revisao.
7. Corrigir CRUD de Metas e criar Programa de Comissao.
8. Implementar Faturas/Pagamentos antes de liberar comissao por recebimento.
9. Eventos de dominio + audit log + automacoes idempotentes.
10. Testes negativos de acesso cruzado entre unidades.
