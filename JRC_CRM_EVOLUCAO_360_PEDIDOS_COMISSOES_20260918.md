# GoPure / JRC CRM — pacote consolidado para homologação local — 2026-09-18

Base: ZIP de produção GoPure `jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907-main` recebido antes desta alteração.

## Objetivo
Fechar o ciclo comercial preservando o JRC Conversas atual e adicionando somente integrações/evoluções do CRM.

## Incluído neste pacote

### Lead / Cliente / Negócio
- Mantido o relacionamento existente Lead → Contact → Deal.
- `Deal` continua vinculado a um contato e um mesmo contato pode possuir vários negócios independentes.
- Novo Negócio pode ser aberto diretamente pelo painel do contato, sem criar um novo Lead.
- Nova tela Cliente 360° com resumo, negócios, propostas, pedidos, contratos e timeline comercial.
- Acesso ao Cliente 360° diretamente da Central de Relacionamentos.
- NICO pode ser aberto do Cliente 360° com prompt comercial contextual.

### Leads e Negócios
- Tabela de Leads compactada para melhor distribuição visual.
- Nova ação segura de excluir Lead.
- Excluir Lead não exclui Contact.
- Se o Lead possuir Negócio vinculado, a exclusão é bloqueada para impedir perda silenciosa de relacionamento.
- Tabela de Negócios compactada, com Cliente agrupado ao título e ação de abertura.

### Propostas
- Preservado o módulo atual de Propostas.
- Responsável da proposta editável e independente do responsável do Negócio.
- `Sem mensalidade` explícito.
- Frete: não se aplica / incluso / cobrado à parte.
- Opção para incluir frete no valor parcelável.
- Condição de pagamento: à vista / entrada + parcelas / parcelado sem entrada.
- Cálculo de parcelas em centavos, com fechamento exato do saldo.
- Observações comerciais passam pelo mesmo fluxo de persistência da Proposal e são usadas no PDF.
- Proposta aceita pode ser convertida em Pedido/Venda pela interface.
- Conversão é idempotente: evita duplicar Pedido ativo para a mesma proposta.

### PDF GoPure
- Logo GoPure em todas as páginas padrão do PDF.
- Identidade visual em verde GoPure.
- Resumo comercial.
- Frete.
- Condição de pagamento.
- Entrada, saldo e parcelamento.
- Recorrência somente quando existir mensalidade.
- Responsável da proposta.
- Observações comerciais.
- Fluxo para conclusão.
- Aceite comercial.

### Pedidos / Vendas
- Nova aba Pedidos.
- Pedido gerado a partir de proposta aceita.
- Snapshot comercial da proposta no momento da venda.
- Cliente, Negócio, Proposta, vendedor, produtos, frete, total, mensalidade e condição de pagamento.
- Tela com indicadores e detalhe lateral.
- Atualização de status do pedido.

### Contratos
- Nova aba Contratos.
- Criação de contrato a partir de Pedido/Venda.
- Status, início, fim, vigência, renovação, reajuste, valor mensal, valor único e observações.
- Relação com Pedido, Negócio, Contact e responsável.

### Metas
- Nova aba Metas.
- Cadastro de meta por vendedor/período ou meta de equipe.
- Valor alvo em reais.
- Estrutura pronta para o realizado ser alimentado pelos Pedidos/Vendas.

### Comissões
- Nova aba Comissões.
- Comissão vinculada a Pedido/Venda e vendedor.
- Base sugerida = produtos menos descontos, sem incluir frete automaticamente.
- Percentual e status: prevista, liberada ou paga.
- Cards de resumo por situação.

### Caixa de Entrada
- Novo filtro avançado `Canal`.
- Permite selecionar WhatsApp, E-mail, Facebook e Instagram.
- Usa o `channel_type` real da Inbox; não cria labels artificiais.
- Pode ser combinado com responsável, status, time e demais filtros atuais.

## Segurança / multi-tenant
- Novas estruturas usam `account_id` e foreign keys.
- Responsáveis, metas e comissões validam usuários dentro da mesma Account.
- Cliente 360° consulta somente registros da Account atual.
- Migrations são aditivas e não removem dados existentes.

## Migrations deste pacote
1. `20260918110000_expand_jrc_crm_commercial_cycle.rb`
2. `20260918120000_add_shipping_in_installments_to_jrc_crm_proposals.rb`

## Validação estática executada ao gerar o ZIP
- `ruby -c` em todos os Ruby alterados/novos: OK.
- `node --check` nos JavaScript alterados: OK.
- scripts de todos os SFC Vue alterados extraídos e validados com `node --check`: OK.

## Ainda precisa ser validado localmente
O ambiente desta geração não possui Bundler/node_modules do projeto, então não foi possível executar Rails/Vite nem a suíte completa.

Antes de produção:
1. subir a base local;
2. executar `bundle exec rails db:migrate`;
3. iniciar Rails, Sidekiq e Vite conforme o compose/dev setup do projeto;
4. validar Lead → Contact → múltiplos Negócios;
5. validar Cliente 360°;
6. validar edição/salvamento de Observações da proposta;
7. gerar PDF e confirmar logo GoPure em todas as páginas;
8. validar frete, à vista, entrada + parcelas e sem mensalidade;
9. aceitar proposta → Converter em Pedido;
10. criar Contrato, Meta e Comissão;
11. validar filtro de canal em Conversas;
12. executar os testes do projeto antes de gerar imagem de produção.

Este pacote é deliberadamente destinado a HOMOLOGAÇÃO LOCAL antes de qualquer deploy de produção.
