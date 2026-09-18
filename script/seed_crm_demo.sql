BEGIN;

-- Massa idempotente para a conta local Grupo JRC (id 1).
INSERT INTO jrc_crm_business_units (account_id, name, code, segment, active, settings, created_at, updated_at)
VALUES (1, 'Demonstração CRM', 'DEMO', 'Demonstração', true, '{}', now(), now())
ON CONFLICT (account_id, code) DO UPDATE SET updated_at = EXCLUDED.updated_at;

INSERT INTO jrc_crm_products (account_id, business_unit_id, name, sku, category, description, unit_price_cents, cost_cents, active, metadata, custom_attributes, tags, available_for, integrations, billing_model, product_type, commission_rate, requires_contract, created_at, updated_at)
SELECT 1, bu.id, product.name, product.sku, product.category, product.description, product.price, product.cost, true, '{}', '{}', '["demo"]', '[]', '[]', product.billing, 'service', 5.0, true, now(), now()
FROM jrc_crm_business_units bu
CROSS JOIN (VALUES
  ('Plano GoPure Premium', 'DEMO-GOPURE-PREMIUM', 'Assinatura', 'Plano mensal para acompanhamento comercial', 49900, 18000, 'monthly'),
  ('Implantação CRM', 'DEMO-IMPLANTACAO', 'Serviços', 'Configuração e treinamento inicial', 250000, 80000, 'one_time'),
  ('Consultoria Comercial', 'DEMO-CONSULTORIA', 'Serviços', 'Pacote de consultoria estratégica', 150000, 45000, 'one_time')
) AS product(name, sku, category, description, price, cost, billing)
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_products p WHERE p.account_id = 1 AND p.sku = product.sku);

INSERT INTO jrc_crm_deals (account_id, business_unit_id, pipeline_id, stage_id, owner_id, contact_id, title, description, value_cents, probability, status, temperature, expected_close_at, currency, metadata, custom_attributes, created_at, updated_at)
SELECT 1, bu.id, 1, stage.id, 1, 1, item.title, item.description, item.value_cents, item.probability, item.status, item.temperature, now() + item.close_in_days * interval '1 day', 'BRL', '{"demo":true}', '{}', now(), now()
FROM jrc_crm_business_units bu
CROSS JOIN (VALUES
  ('Demonstração CRM - Expansão GoPure', 'Oportunidade de expansão do plano mensal.', 499000, 70.0, 'open', 'hot', 10, 'proposal_sent'),
  ('Demonstração CRM - Implantação concluída', 'Venda aprovada para teste de pedidos, contratos e comissões.', 299900, 100.0, 'won', 'warm', -5, 'won'),
  ('Demonstração CRM - Consultoria estratégica', 'Negociação em andamento.', 150000, 50.0, 'open', 'warm', 20, 'negotiation')
) AS item(title, description, value_cents, probability, status, temperature, close_in_days, stage_key)
JOIN jrc_crm_stages stage ON stage.account_id = 1 AND stage.pipeline_id = 1 AND stage.key = item.stage_key
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_deals d WHERE d.account_id = 1 AND d.title = item.title);

INSERT INTO jrc_crm_proposals (account_id, business_unit_id, deal_id, owner_id, title, proposal_number, public_token_digest, status, subtotal_cents, total_cents, implementation_cents, monthly_cents, valid_until, term_months, solution_description, payment_condition, installments_count, created_at, updated_at)
SELECT 1, bu.id, deal.id, 1, 'Proposta demonstração — Implantação GoPure', 'PROP-DEMO-001', md5('PROP-DEMO-001'), 'sent', 299900, 299900, 250000, 49900, current_date + 20, 12, 'Implantação e assinatura GoPure Premium para demonstração.', 'cash', 1, now(), now()
FROM jrc_crm_business_units bu
JOIN jrc_crm_deals deal ON deal.account_id = 1 AND deal.title = 'Demonstração CRM - Implantação concluída'
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_proposals WHERE account_id = 1 AND proposal_number = 'PROP-DEMO-001');

INSERT INTO jrc_crm_proposal_items (proposal_id, product_id, name_snapshot, quantity, unit_price_cents, total_cents, billing_model, unit_name, initial_total_cents, recurring_total_cents, created_at, updated_at)
SELECT proposal.id, product.id, product.name, 1, product.unit_price_cents, product.unit_price_cents, product.billing_model, 'unidade', product.unit_price_cents, CASE WHEN product.billing_model = 'monthly' THEN product.unit_price_cents ELSE 0 END, now(), now()
FROM jrc_crm_proposals proposal
JOIN jrc_crm_products product ON product.account_id = 1 AND product.sku IN ('DEMO-IMPLANTACAO', 'DEMO-GOPURE-PREMIUM')
WHERE proposal.account_id = 1 AND proposal.proposal_number = 'PROP-DEMO-001'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_proposal_items item WHERE item.proposal_id = proposal.id AND item.product_id = product.id);

INSERT INTO jrc_crm_sales_orders (account_id, business_unit_id, deal_id, proposal_id, contact_id, owner_id, order_number, status, products_cents, total_cents, monthly_cents, payment_condition, payment_method, sold_at, closed_at, notes, snapshot, source_type, created_at, updated_at)
SELECT 1, bu.id, deal.id, proposal.id, 1, 1, 'PED-DEMO-001', 'completed', 299900, 299900, 49900, 'cash', 'pix', now() - interval '5 days', now() - interval '4 days', 'Pedido demonstrativo concluído.', '{"demo":true}', 'proposal', now(), now()
FROM jrc_crm_business_units bu
JOIN jrc_crm_deals deal ON deal.account_id = 1 AND deal.title = 'Demonstração CRM - Implantação concluída'
JOIN jrc_crm_proposals proposal ON proposal.account_id = 1 AND proposal.proposal_number = 'PROP-DEMO-001'
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_sales_orders WHERE account_id = 1 AND order_number = 'PED-DEMO-001');

INSERT INTO jrc_crm_order_items (sales_order_id, product_id, name, quantity, unit_cents, one_time_cents, recurring_cents, snapshot, created_at, updated_at)
SELECT ord.id, product.id, product.name, 1, product.unit_price_cents, CASE WHEN product.billing_model = 'one_time' THEN product.unit_price_cents ELSE 0 END, CASE WHEN product.billing_model = 'monthly' THEN product.unit_price_cents ELSE 0 END, '{"demo":true}', now(), now()
FROM jrc_crm_sales_orders ord
JOIN jrc_crm_products product ON product.account_id = 1 AND product.sku IN ('DEMO-IMPLANTACAO', 'DEMO-GOPURE-PREMIUM')
WHERE ord.account_id = 1 AND ord.order_number = 'PED-DEMO-001'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_order_items item WHERE item.sales_order_id = ord.id AND item.product_id = product.id);

INSERT INTO jrc_crm_contracts (account_id, business_unit_id, sales_order_id, deal_id, contact_id, owner_id, contract_number, status, starts_on, ends_on, term_months, monthly_cents, one_time_cents, contract_type, payment_condition, auto_renew, notes, created_at, updated_at)
SELECT 1, bu.id, ord.id, deal.id, 1, 1, 'CTR-DEMO-001', 'active', current_date - 4, current_date + interval '12 months', 12, 49900, 250000, 'subscription', 'cash', true, 'Contrato demonstrativo ativo.', now(), now()
FROM jrc_crm_business_units bu
JOIN jrc_crm_sales_orders ord ON ord.account_id = 1 AND ord.order_number = 'PED-DEMO-001'
JOIN jrc_crm_deals deal ON deal.account_id = 1 AND deal.title = 'Demonstração CRM - Implantação concluída'
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_contracts WHERE account_id = 1 AND contract_number = 'CTR-DEMO-001');

INSERT INTO jrc_crm_sales_commissions (account_id, sales_order_id, user_id, base_cents, rate_percent, commission_cents, status, released_at, notes, created_at, updated_at)
SELECT 1, ord.id, 1, 299900, 5.0, 14995, 'released', now() - interval '3 days', 'Comissão demonstrativa do pedido PED-DEMO-001.', now(), now()
FROM jrc_crm_sales_orders ord
WHERE ord.account_id = 1 AND ord.order_number = 'PED-DEMO-001'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_sales_commissions c WHERE c.account_id = 1 AND c.sales_order_id = ord.id AND c.user_id = 1);

INSERT INTO jrc_crm_sales_goals (account_id, business_unit_id, user_id, scope_kind, metric, period_start, period_end, target_cents, target_quantity, created_at, updated_at)
SELECT 1, bu.id, 1, 'user', 'revenue', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date, 1500000, 10, now(), now()
FROM jrc_crm_business_units bu
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_sales_goals WHERE account_id = 1 AND user_id = 1 AND period_start = date_trunc('month', current_date)::date);

INSERT INTO jrc_crm_activities (account_id, business_unit_id, deal_id, contact_id, user_id, title, description, activity_type, status, due_at, completed_at, metadata, created_at, updated_at)
SELECT 1, bu.id, deal.id, 1, 1, activity.title, activity.description, activity.kind, activity.status, now() + activity.days * interval '1 day', CASE WHEN activity.status = 'completed' THEN now() - interval '1 day' END, '{"demo":true}', now(), now()
FROM jrc_crm_business_units bu
JOIN jrc_crm_deals deal ON deal.account_id = 1 AND deal.title = 'Demonstração CRM - Expansão GoPure'
CROSS JOIN (VALUES
  ('Demonstração do plano Premium', 'Apresentar os benefícios do plano.', 'demonstration', 'scheduled', 2),
  ('Follow-up comercial', 'Confirmar decisão do cliente.', 'follow_up', 'scheduled', 5),
  ('Contato inicial realizado', 'Conversa de qualificação concluída.', 'whatsapp', 'completed', -2)
) AS activity(title, description, kind, status, days)
WHERE bu.account_id = 1 AND bu.code = 'DEMO'
  AND NOT EXISTS (SELECT 1 FROM jrc_crm_activities a WHERE a.account_id = 1 AND a.title = activity.title);

COMMIT;
