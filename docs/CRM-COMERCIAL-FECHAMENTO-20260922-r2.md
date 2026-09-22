# JRC Conversas CRM - Fechamento do checkpoint comercial
## Revisão r2 de 22/09/2026

**Status: candidato final de código entregue; homologação integrada ainda pendente.**

O checkpoint foi continuado, não reconstruído. Os testes isolados executáveis passaram depois das correções. Rails/RSpec, Vue/Vitest, build Vite e o runtime NICO completo foram efetivamente tentados, mas ficaram bloqueados pelas dependências e versões ausentes neste ambiente. Este documento não os apresenta como aprovados.

O pacote está preparado para Git e para a etapa de validação/build da imagem. **Não está liberado para produção sem o gate integrado e o aceite funcional no navegador.** Nenhum servidor, banco de cliente, credencial externa ou conta de produção foi acessado nesta execução.

## 1. Origem, preservação e auditoria

Entrada: `JRC-CRM-COMMERCIAL-CODEX-CHECKPOINT-20260922.zip`.

SHA-256 da entrada: `a9845c5a02b728bcd5edd989ada756bc05454ede8d8cbe6535edaa94193e9cb5`.

Foram inventariados 9.705 arquivos do ZIP e verificadas sua integridade, estrutura e trilha de alterações. Os separadores Windows do arquivo compactado foram normalizados para caminhos POSIX no novo ZIP. Não houve extração por cima do arquivo original.

Foram lidos o status, o diff, o relatório de validação anterior e os testes comerciais/frontend. A verificação reversa do diff recebido (`git apply --reverse --check`) passou antes das alterações: o diff era compatível com o código efetivamente recebido. Os três documentos originais foram preservados como histórico; não são evidência de execução nesta r2.

A revisão funcional e de código concentrou-se nos controllers, models, serializers, serviços financeiros/documentais, contatos, componentes comerciais, permissões e testes do escopo. Inventário completo e comparação por hash não significam revisão manual de cada linha dos 9.705 arquivos.

Há 16 arquivos existentes alterados adicionalmente e 10 novos arquivos de código/testes, antes de contar os documentos e evidências desta entrega. O inventário final discriminado acompanha o pacote. Nenhum arquivo-fonte original foi retirado. Foram excluídos do empacotamento 281 arquivos pré-compilados de `public/vite-test`, já ignorados pelo Git, além de saídas temporárias geradas durante as tentativas locais de build. Esses artefatos devem ser recompilados, não reutilizados como prova da nova interface.

284 arquivos identificados por caminhos de NICO/WhatsApp/Instagram/Facebook/PABX permaneceram idênticos por hash. Isso comprova preservação desses arquivos, mas não substitui regressão integrada. Gemfile, lockfiles, versões-alvo, schema e migrations foram preservados. O modelo ONNX em `vendor/db` continua no pacote: é um recurso da aplicação, não um dump de banco.

## 2. O que já estava implementado e foi preservado

| Área | Estado encontrado no checkpoint | Verificação nesta execução |
|---|---|---|
| Contatos: Pessoas | Filtro SQL para contatos sem empresa associada/nome de empresa. | Código e specs revisados; integração SQL bloqueada. |
| Contatos: Empresas | Contatos vinculados a empresa ou com `company_name`; não um cadastro paralelo inventado. | Código e specs revisados. |
| Grupos | Agrupamento por etiquetas existentes. | Filtro server-side preservado; validação Rails pendente. |
| Sem responsável | Ausência de vínculo com lead/negócio que tenha owner, dentro da conta. | Subconsultas por Account revisadas. |
| Duplicados | Candidatos por e-mail normalizado, telefone e identificador, na mesma conta. | Não mescla nem exclui contatos. Execução SQL pendente. |
| Busca em toda a base | Busca de nome, e-mail, telefone, identificador e empresa no backend da conta, não só nos contatos carregados. | Endpoints, normalização e specs de resultados além da primeira página revisados. |
| Paginação | Páginas de 15 contatos, desempate por ID, contagem e `has_more`. | Corrigidas páginas zero/negativas; navegação integrada pendente. |
| Seletor de cliente dos Pedidos | Busca/paginação por API e seleção por ID, não por posição da lista. | Preservado; limpeza imediata ao trocar Account adicionada. |
| Produtos | Modelo de cobrança, valor, quantidade, prazo opcional, integrações/implantação e CRUD administrativo. | Model/controller/specs revisados, sem regravar produtos históricos. |
| Venda direta | Cobrança única não herda MRR antigo. | Calculador real executado: 100 x R$20 = R$2.000, MRR zero. |
| Recorrência e implantação | Modelo de cobrança independente da necessidade de implantação. Valor inicial unitário da recorrência multiplicado pela quantidade. | Cenários isolados reais do calculador passaram. |
| Descontos, frete, impostos e acréscimos | Desconto do item afeta seu preço; desconto geral/frete/impostos/acréscimos compõem o valor inicial conforme a regra existente. | Sem trocar regras comerciais por marca. Casos e entradas inválidas testados. |
| MRR e valor contratual | MRR separado do inicial; valor contratual quando todos os itens recorrentes pertinentes têm prazo conhecido. | Correção adicional de arredondamento anual e normalização do prazo. |
| Pedidos mistos | Itens únicos e recorrentes no mesmo pedido, sem somar MRR ao inicial. | R$3.750 iniciais e R$780 de MRR no cenário isolado descrito abaixo. |
| Salvar/reabrir | Cálculo backend, transação, campos financeiros e snapshots; edição sem substituir dados legados indevidamente. | Specs de persistência mantidos. Round-trip JSON isolado não foi contado como teste de banco. Persistência real ainda pendente. |
| Wizard | Cinco etapas; operação pulada quando não aplicável; Anterior/Próximo/Finalizar; preview backend; validações. | Estrutura e specs preservados; não houve montagem Vue/navegador nesta execução. |
| Rodapé e rolagem | Navegação fora da região rolável, com proteção durante salvamento. | Inspeção de código; aceite visual no navegador pendente. |
| Próximos passos | Atividades vinculadas ao pedido, criação/conclusão e agendamento de follow-up. | Ajustado horário ao editar; persistência/associações aguardam Rails. |
| Funis e Etapas | CRUD, permissão administrativa, exclusão em uso bloqueada e reordenação. | Parser de entrada testado; validação transacional/SQL pendente. |
| Permissões e tenant | `Current.account`/`crm_scope`, associações da mesma conta, escopo por owner para agente e operações administrativas protegidas. | Inspeção e specs negativos preservados/ampliados; não certificados dinamicamente aqui. |
| GoPure | Tema visual, não um seletor de regra comercial. | Opt-in/opt-out testado em helper; PDFs corrigidos para empresa e configuração da conta. |
| PDFs/documentos | Geração local de pedidos, propostas e contratos. | Serviços reais renderizados com fixtures sintéticas; correções de paginação e marca abaixo. |
| E-mail dos Pedidos | Controles de envio desabilitados, aviso de indisponibilidade e `communication_available: false`. | Preservado. Não foi simulado, disparado ou confirmado um envio externo inexistente. |
| CRM/NICO/WhatsApp | Fluxos e integrações existentes preservados. | Testes isolados abaixo; regressão integrada ainda exige runtime/dependências. |

A entrega de propostas pela caixa de entrada existente é distinta do e-mail automático dos Pedidos. O serviço existente cria mensagem/anexo na conversa; isso não comprova recebimento pelo destinatário. SMTP/Sidekiq/provedor e assinatura externa não foram exercitados aqui.

## 3. Correções adicionais da r2

### Financeiro

O valor anual contratado era calculado a partir do MRR já arredondado. R$100 anuais durante 12 meses podiam virar R$99,96. Agora o cálculo contratual usa o valor anual líquido real e arredonda depois da aplicação do prazo; o MRR continua R$8,33 como métrica mensal arredondada.

Itens anuais de valor positivo cujo MRR arredonda para zero deixavam de integrar o total contratado. Foram incluídos no critério correto. Foi corrigido também o caso de prazo numérico textual validado como 100, mas posteriormente truncado para 1 (`1e2`): o snapshot usa o inteiro validado.

Modelos de cobrança explícitos desconhecidos agora são recusados, em vez de cair silenciosamente em venda única. Percentuais de desconto acima de 100% são rejeitados mesmo sobre base zero. Valores legados sem modelo explícito continuam com seu tratamento de compatibilidade. Não houve recálculo em massa de pedidos existentes.

### PDFs e identidade

Reproduzidos oito testes falhando no renderer recebido: aceite de proposta fora da página, textos longos ultrapassando a área útil, contratos limitados aos sete primeiros itens, marca GoPure fixa para outras empresas e escape incorreto de barras invertidas em strings PDF.

Foram adicionadas continuações de página para itens, descrições, observações e cláusulas, reservando rodapé/assinaturas. O contrato mostra inicial e MRR separadamente, sem somar medidas diferentes numa coluna ambígua. A proposta preserva o texto completo na seção detalhada; a capa usa resumo quando necessário.

Propostas/contratos usam a identidade da empresa da conta. O logo obedece ao mesmo `crm_theme` de opt-in/opt-out do frontend, com fallback para recurso JRC existente, em vez do caminho inexistente `logo.png`. As cores e a estrutura já existentes foram preservadas. A alteração de marca não altera preços ou recorrência.

### Atividades, contatos e etapas

A edição de atividade convertia o instante para o fuso do navegador e reenviava esse horário sem fuso para uma API que interpreta o fuso da conta. Foi reproduzido 10h virando 13h em navegador UTC. O serializer agora fornece `due_at_input` no horário da conta; o formulário usa esse campo, com compatibilidade para `due_at_display`. O contrato já existente do wizard de enviar `datetime-local` no fuso da conta foi preservado.

A busca normaliza páginas menores que 1 para a primeira página, evitando OFFSET negativo. O seletor limpa os contatos já exibidos imediatamente ao mudar de Account e invalida respostas de seleção obsoletas, inclusive após desmontagem.

A reordenação de etapas não trunca mais IDs/posições fracionários ou malformados. Rejeita duplicidades e colisão com etapas não incluídas na reordenação parcial. Mantém a transação, o escopo por conta e o bloqueio administrativo, serializando reordenações no mesmo funil. A parte de banco aguarda execução integrada.

### Gate de entrega

O workflow mantém validação antes da publicação, inclui o build explícito dos assets de teste, ImageMagick e os novos testes isolados. A tag de aplicação foi reservada como `4.16.2-gopure-crm-comercial-20260922-r2`. **Nenhuma imagem foi publicada e nenhum workflow remoto foi executado nesta conversa.**

## 4. Resultado dos testes desta execução

| Grupo executado | Resultado final |
|---|---:|
| Calculador comercial real, sem Rails/banco | 23 testes, 66 assertions; zero falhas |
| Entradas de etapas/página e identidade visual, isolados | 7 testes, 39 assertions; zero falhas |
| Serviços PDF reais com fixtures e formatação monetária isolada | 9 testes, 31 assertions; zero falhas |
| Helper frontend de horário da atividade | 6 testes; zero falhas |
| Serviços isolados WhatsApp 24h existentes | 41 testes, 123 assertions; zero falhas |
| Lógica frontend WhatsApp isolada existente | 17 testes; zero falhas |
| Contratos de dados NICO/ERP, isolados | 9 testes; zero falhas |
| **Total distinto dos grupos isolados acima** | **112 testes aprovados** |

Os 112 não são a suíte Rails ou a suíte Vue. Não foram somados testes repetidos nas diferentes rodadas. Há logs de falhas antes e sucesso depois; uma rodada final foi feita após a última alteração do calculador.

Verificações adicionais: sintaxe de 35 arquivos Ruby; parsing de scripts de 31 arquivos JS/TS/Vue sem erros; YAML do workflow e JSONs do projeto válidos. Parsing do bloco `<script>` **não compila o template Vue**, não resolve imports e não substitui Vitest/Vite. A verificação heurística de padrões fortes de segredos não encontrou candidatos no conjunto textual inspecionado, mas não é certificação de ausência de informação sensível.

Foram gerados seis PDFs sintéticos com os serviços reais (33 páginas), renderizados e inspecionados, sem texto fora dos limites na verificação geométrica final. As fixtures não usam dados de clientes. O teste isolado substitui somente a dependência de formatação Rails e omite logos: **MiniMagick/logo em runtime Rails e dados persistidos ainda precisam do gate integrado**.

| Tentativa integrada | Resultado observado, não aprovado |
|---|---|
| Rails/RSpec completo relevante (CRM, policies, contatos, NICO, governança) | Bundler bloqueou: Ruby local 3.3.8 versus 3.4.4 exigido; gems ausentes. Nenhum exemplo RSpec desta tentativa executou. |
| Vitest comercial/NICO | `node_modules/vitest` ausente. Suíte não iniciou. |
| Build frontend Vite | `node_modules/vite` ausente. Build não iniciou. |
| Rotas CRM com Vue | Falha de carregamento: módulo `vue` ausente. |
| NICO runtime completo | Nove contratos puros passam; cinco arquivos de teste falham ao carregar dependências. Não é aprovação da suíte completa. |
| Build NICO | Falha: `@elizaos/core` e tipos/dependências Node ausentes. Compilador local não substitui o toolchain travado. |
| Instalação local de dependências | Bundler recusou a versão Ruby; Corepack/pnpm não conseguiu obter o pacote pela rede. Não foram alterados os lockfiles para contornar isso. |

Os 179 Rails, 130 frontend e build informados anteriormente permanecem apenas como registro histórico. **Não foram revalidados neste ambiente.** Os specs existentes foram preservados/ampliados para execução no runtime apropriado.

### Cenários financeiros efetivamente reexecutados

Venda direta: 100 unidades x R$20 = R$2.000 iniciais, MRR R$0, sem prazo contratual artificial. Com desconto geral R$200, frete R$100, impostos de 10% sobre R$1.900 e acréscimo R$5, o inicial passa a R$2.095, MRR zero.

Recorrência: 20 ramais x R$39/mês, valor inicial unitário R$50: R$1.000 iniciais, MRR R$780; em 12 meses, R$9.360 de recorrência contratada e R$10.360 globais. Com e sem implantação, a recorrência permanece independente.

Pedido misto: venda direta R$2.000 + R$1.000 iniciais da recorrência + cinco serviços de R$150 = R$3.750 iniciais; MRR R$780. Sem prazo conhecido para a recorrência, o total contratual não é inventado. Também foram executados quantidade fracionária válida, rejeição de precisão inválida, descontos por item/gerais, arredondamento anual e rateio de parcelas.

## 5. Migrations e dados

**Nenhuma migration nova foi criada nesta continuação.** Permanece a migration do checkpoint `20260922160000_extend_commercial_order_activities.rb`: referência opcional de atividade para pedido com índice/FK; prazo do produto nullable e sem default artificial de 12 meses.

Ela não foi aplicada aqui. No destino, verificar todas as pendentes com `db:migrate:status`, pois a situação real do servidor não foi consultada. Não se pode concluir que apenas essa migration estará pendente no servidor.

Não foram executados `db:drop`, `db:reset`, exclusão de dados, seeds em produção nem recálculo histórico. O `down` existente bloqueia rollback que perderia vínculos de atividades ou inventaria prazos. A estratégia segura de recuperação é imagem anterior compatível com o schema, ou correção para frente; restauração de backup somente mediante decisão operacional explícita.

## 6. Pendências reais para liberação

O bloqueio principal é de validação: executar Ruby 3.4.4, Node 24.x, pnpm 10.2.0, Bundler 2.5.16 e dependências dos lockfiles, com PostgreSQL/pgvector e Redis de teste. Essas versões são as do projeto recebido, não uma atualização arbitrária desta r2.

Aprovar RSpec/Vitest/build/runtime completo, mais persistência real após salvar/reabrir, controles de acesso com admin/agente em duas contas, busca/paginação, wizard/rodapé/rolagem e atividades em navegador. As correções novas de interface e SQL não estão dispensadas dessa verificação.

Para integrações reais, confirmar as configurações existentes: caixas e credenciais Meta/WhatsApp, templates aprovados, webhooks, SMTP/Sidekiq quando aplicável, NICO/provider/ERP e eventual provedor de assinatura. Não foi demonstrada falta dessas configurações no servidor; simplesmente não foram acessadas nem testadas aqui. Não é necessário inventar credenciais ou alterar integrações para revisar o código.

O envio automático de confirmação/cronograma dos Pedidos continua indisponível de forma explícita. Isso é uma limitação funcional preservada, não um envio simulado como bem-sucedido.

## 7. Entrega e deploy

O ZIP completo inclui código, testes, migrations existentes, Docker/workflow, recursos originais, relatório, roteiro de deploy, diff incremental, inventário e logs. **Os diffs são evidência; as alterações já estão aplicadas. Não reaplicar o diff antigo nem o novo sobre este ZIP.**

Consultar `docs/DEPLOY-CRM-COMERCIAL-20260922-r2.md`. O fluxo de liberação é: branch Git de revisão, gate integrado aprovado, build da imagem r2, backup e conferência do banco, migrations pendentes, mesma imagem em Rails/Sidekiq, smoke tests e aceite. Preservar PostgreSQL, Redis, volumes, segredos, domínios e configurações existentes. Não há deploy automático executado por esta entrega.

Os logs detalhados ficam em `docs/qa/20260922-r2/`. `MANIFEST-SHA256.txt` permite conferir os arquivos listados, excluindo ele próprio. O ZIP de evidências separado contém também as renderizações PDF sintéticas antes/depois.
