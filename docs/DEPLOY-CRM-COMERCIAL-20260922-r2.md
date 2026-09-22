# Deploy do candidato comercial r2 - 22/09/2026

**Não publicar em produção antes do gate integrado e do aceite no navegador.** O pacote foi corrigido e testado isoladamente; RSpec/Vitest/build completos não rodaram neste ambiente. A tag r2 está reservada no workflow, não publicada.

## Preparar o Git (Windows / estação de desenvolvimento)

Extraia o ZIP numa pasta nova e preserve o checkpoint/anterior. O diretório interno é `JRC-CRM-COMMERCIAL-FINAL-20260922-r2`. O código já contém as correções; não execute os diffs como instaladores.

Use uma branch de revisão no repositório existente. Preserve o diretório `.git` do repositório de destino, revise o diff antes do commit e não sobrescreva credenciais/configurações locais. O ZIP não leva `.env` de produção; mantenha os segredos fora do Git. Não é necessário recriar banco, Redis ou volumes para uma nova versão.

## Gate de homologação (runner Linux / ambiente exclusivo de teste)

O workflow `.github/workflows/build-ghcr.yml` usa as versões do projeto: Ruby 3.4.4, Node 24.13.0, pnpm 10.2.0 e Bundler 2.5.16. Instala ImageMagick/libvips e dependências travadas. A publicação depende do job `validate`.

Executar o workflow por `workflow_dispatch` na branch revisada, ou o fluxo de integração da equipe. Conferir que está usando o commit r2 correto. O schema load que já existia no workflow só se destina ao banco **novo e exclusivo do serviço de CI**; nunca copiá-lo para um servidor com dados.

O gate inclui RSpec de CRM/contatos/policies/NICO/governança, Vitest comercial/NICO, rotas Vue, WhatsApp 24h, testes adicionais isolados e build/test do runtime. A etapa Vite de teste serve aos specs Rails; o Dockerfile recompila assets de produção para a imagem. Não reutilize `public/vite-test` do checkpoint anterior.

Critério: nenhum grupo integrado pode ser substituído por contagens isoladas. Resolver qualquer falha do runner e reexecutar o grupo afetado antes da liberação. Não reduzir versões, retirar asserts ou afrouxar isolamento para obter sucesso.

## Aceite no navegador (homologação, não produção)

Usar dados de teste e duas Accounts, com administrador e agente. Conferir as cinco abas de contatos, filtros combinados, busca além da primeira página, ir/voltar páginas e trocar Account durante o carregamento do seletor.

Criar venda direta de 100 unidades x R$20: inicial R$2.000, MRR zero, sem implantação. Salvar, fechar, reabrir e editar com desconto R$200, frete R$100, imposto 10% e acréscimo R$5: inicial R$2.095. Repetir com pedido recorrente com/sem implantação, anual e misto; conferir os valores persistidos e PDFs.

Verificar Anterior/Próximo/Finalizar, bloqueios de validação, rodapé e rolagem em janela menor. Criar/editar/concluir atividade; manter o mesmo horário da conta mesmo com navegador em outro fuso. Confirmar que o agente não administra produtos/funis nem consulta pedidos de outro owner/Account fora de sua permissão. Confirmar as recusas da API, não apenas botões ocultos.

Gerar proposta/contrato com mais de sete itens e observações extensas. Conferir todas as páginas, marca, valores, acentos, logos e assinaturas sem corte. O e-mail automático dos Pedidos deve continuar claramente indisponível; eventual envio real por caixa de entrada precisa de confirmação no provedor, não só de mensagem criada na aplicação.

## Backup e conferência (servidor, antes da alteração)

O administrador deve confirmar a instância/banco efetivos, obter backup PostgreSQL completo verificado, preservar anexos/storage, `.env`/segredos, definição atual da stack e tag/digest da imagem anterior. Guardar o backup fora do container descartável. Nomes reais de serviços/banco não foram inferidos nesta entrega.

**Dentro do container Rails candidato, com as variáveis do destino conferidas, somente leitura:**

```sh
RAILS_ENV=production bundle exec rails db:migrate:status
```

Verificar todas as migrations pendentes. A `20260922160000` do checkpoint adiciona o vínculo opcional atividade/pedido e remove o default artificial do prazo do produto. Esta r2 não acrescenta migration.

## Aplicar a versão (servidor, após aprovação operacional)

Usar a mesma imagem candidata aprovada em Rails e Sidekiq:

`4.16.2-gopure-crm-comercial-20260922-r2`

O workflow mantém o registry/repositório de imagem já configurado. Conferir o digest publicado pelo job, não apenas o nome da tag. Não há imagem r2 publicada por esta conversa.

Em janela controlada, aplicar migrations uma única vez no banco correto, antes de liberar tráfego para o código que depende delas. **Dentro do container Rails candidato:**

```sh
RAILS_ENV=production bundle exec rails db:migrate
```

Confirmar novamente o estado, somente leitura:

```sh
RAILS_ENV=production bundle exec rails db:migrate:status
```

Atualizar/reiniciar Rails e Sidekiq pelo gerenciador da stack existente. Preservar PostgreSQL, Redis, redes, storage, domínios, filas, variáveis NICO, credenciais Meta e demais integrações. Não criar bancos/volumes paralelos automaticamente nem executar `down -v`. O código do serviço NICO não mudou e não exige troca arbitrária de sua imagem/configuração.

## Conferência pós-deploy e recuperação

Conferir saúde da aplicação, workers/filas, logs de erro, contatos, consulta a pedido existente, PDFs, uma operação comercial autorizada de teste e recebimento/envio aprovado nas integrações necessárias. Não enviar mensagens reais ou cadastrar dados de cliente sem aprovação da equipe.

Diante de regressão, suspender liberação e avaliar retorno à imagem anterior **compatível com o schema**. Não executar rollback destrutivo: o `down` da migration bloqueia perda de vínculos ou invenção de prazos. Restauração de backup pode descartar gravações posteriores e exige decisão explícita. Não executar `db:drop` ou `db:reset`.
