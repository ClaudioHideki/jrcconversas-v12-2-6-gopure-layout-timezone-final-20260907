# GoPure — correções comerciais r3 (23/09/2026)

## Base e preservação

Continuação de `crm-comercial-r2-20260922`, HEAD remoto conferido por fetch em `f955fbb` (checkpoint `51b86f2`). O trabalho da árvore anterior `6467d6c` foi comparado: o checkpoint r2 já incorpora sua implementação e evoluções posteriores. Nenhum reset, merge na main, alteração de produção ou substituição de arquivos locais anteriores foi realizado. Trabalho isolado em `gopure-crm-r2-fixes-20260923`.

## Diagnóstico e correções

- **Metas:** a interface somava metas de métricas diferentes, descartava quantidades no resumo e consultava sempre o mês atual. Agora seleciona uma meta e seu período, exibe a unidade correta, método, responsável e status considerados. O gráfico usa o mesmo cálculo do realizado. Agentes recebem somente seu realizado e ranking; filtros de equipe são aplicados. Pedidos de mesmo valor são contados individualmente mesmo com filtro de produto. O detalhamento por produto usa os itens dos pedidos elegíveis, sem multiplicar o total de um pedido por suas linhas.
- **Status das metas:** retirado o filtro oculto `approved/invoiced` da criação de novas metas; prevalece o método de cálculo. Filtros explícitos históricos permanecem preservados e visíveis, sem regravar dados. Uma meta de pedidos usa pedidos; uma meta de negócios ganhos usa negócios, sem somar a mesma venda pelas duas fontes.
- **Cliente no Novo negócio:** o select consultava apenas `ContactsAPI.get(1)`. O modal e a edição reutilizam o seletor existente com busca no backend, paginação e proteção ao trocar Account. Adicionado bloqueio de clique duplicado ao salvar.
- **Oportunidade pela conversa:** reproduzido no endpoint real `/sales/opportunities` o erro `ArgumentError: invalid argument to TimeZone[]: nil` quando a conta não tem fuso configurado. Corrigido com o fallback já empregado pelo CRM; criação, atividade seguinte, idempotência e acesso à conversa/Account cobertos por requests. A imagem de produção sozinha não comprova que esse era o único erro naquele servidor; logs de produção não foram acessados.
- **Agenda:** o botão Atualizar usava uma classe de cor não definida na configuração Tailwind; agora usa o token de marca, com contraste e estado de carregamento.
- **Wizard e PDFs:** as regras financeiras r2 já estavam corretas nos cenários solicitados. Preservadas e testadas por preview, gravação, consulta e PDF: venda direta 100 × R$20 = R$2.000 iniciais/MRR zero; mensalidade de R$30 sem taxa inicial = inicial zero/MRR R$30/contrato de 12 meses R$360. Nenhuma implantação criada quando o produto não a exige. Não foi somado MRR ao valor inicial artificialmente, nem alterado o cadastro de produtos reais.

## Validação local

Ambiente Linux em Docker com `RAILS_ENV=test`, PostgreSQL exclusivo `gopure_r2_test` em tmpfs, Redis exclusivo e dados sintéticos. Volumes existentes de dependências montados somente para leitura. Nenhum banco ou volume com dados reais foi alterado.

- Rails CRM, NICO, governança, contatos, isolamento, policies e superadmin: **256 exemplos, 0 falhas, 0 pendentes** (`tmp/r3-rails-final.json`). Uma primeira rodada identificou SKU repetido no novo fixture; o fixture foi corrigido e toda a bateria reexecutada.
- Frontend CRM/NICO: **136 testes, 0 falhas** (`tmp/r3-frontend-final.json`). Inclui cliente da segunda página, busca global no Novo negócio e meta quantitativa.
- Financeiro isolado: **23 testes/66 assertions**; entradas: **7/39**; PDF: **9/31**; helpers de frontend: **6 testes**.
- WhatsApp: **41 testes Ruby/123 assertions** e **67 testes Node combinando frontend/roteamento CRM**.
- NICO runtime: **17 testes aprovados** e build TypeScript aprovado, em modo fixture/provedor simulado.
- Build Vite local concluído com exit code 0; o workflow recompila o SHA final antes de publicar. Avisos de Browserslist/deprecações das dependências não impediram as suítes.
- RuboCop Lint nos arquivos Ruby novos/alterados: aprovado. ESLint do novo arquivo de regressão: aprovado. O lint amplo das telas legadas ainda acusa formatação/i18n e problemas anteriores; não foi apresentado como integralmente aprovado e não foram removidas regras.
- PDFs reais gerados pelos requests e renderizados: página financeira da venda direta e da mensalidade inspecionadas, com os valores acima. Artefatos ficam em `tmp/`, fora do Git.

- Navegador local: negócio salvo com Pessoa QA 015 na página 2 entre 94 contatos; busca Pessoa QA 093 encontrou o último contato da base. Botão Atualizar agenda conferido visualmente no tema GoPure e acionado sem erro de console. Somente dados sintéticos.

## Publicação

Workflow existente `.github/workflows/build-ghcr.yml`, acionamento manual na mesma branch e validação obrigatória antes da matrix:

- app: `docker/Dockerfile`; tag `4.16.2-gopure-crm-comercial-20260923-r3`.
- nico-runtime: `docker/nico-runtime.Dockerfile`; tag `nico-runtime-gopure-crm-comercial-20260923-r3`.
- Ambas no pacote `ghcr.io/claudiohideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907`, com tags adicionais `app-sha-<SHA completo>` e `nico-runtime-sha-<SHA completo>`.

Tags r2/homologadas preservadas. O resultado do Actions, SHA e digests efetivamente publicados serão informados na entrega; a configuração deste arquivo não comprova publicação.

## Limites

Sem deploy ou mudanças no Dokploy, credenciais ou dados de produção. Provedores externos reais (OpenAI, WhatsApp/SMTP, ERP/telefonia) não foram acionados nesta validação. Envio comercial de e-mail indisponível no checkpoint continua explicitamente indisponível, sem sucesso fictício. A revisão de produtos históricos eventualmente cadastrados como mensais depende de identificar cada produto real; não houve conversão automática de mensalidades em vendas únicas.
