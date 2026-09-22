# Implementação e verificações - 21/09/2026

## Base e preservação

Base: `jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907-main (2).zip`.

A atualização foi aplicada a uma cópia extraída. Nenhum arquivo original foi excluído. Foram preservados os arquivos de dependências, Docker, workflows de publicação, variáveis de exemplo e estrutura de banco. O manifesto informa os arquivos modificados/adicionados e os hashes SHA-256.

Não houve acesso ao servidor do cliente, uso de credenciais reais, envio de mensagens reais ou alteração de dados de produção.

## Adaptação do handoff ao projeto existente

O handoff sugere novas tabelas e um adapter. Para não criar um sistema paralelo, esta implementação reutiliza os recursos existentes do Chatwoot/JRC:

- `account_id` isola a empresa; `inbox_id` isola a caixa/conta WhatsApp; `team_id` define a equipe da conversa. Não foram criados campos `tenant_id` ou `business_unit_id` adicionais.
- `Channel::Whatsapp.message_templates` armazena o catálogo do provedor. `provider_config.jrc_template_settings` armazena regras internas, favoritos, origens das variáveis e resultado da sincronização. As credenciais existentes são preservadas.
- `Message.additional_attributes.template_params` conserva os parâmetros. `whatsapp_template_audit` conserva identificadores, versão derivada dos componentes, agente, equipe, status e horários de acompanhamento. Não foram criadas tabelas duplicadas de templates, variáveis ou logs.
- Os adapters existentes de Meta Cloud e 360dialog continuam responsáveis pelo envio. Não foi criada integração com Broker, BRD ou novos provedores.

## Janela e envio

`Whatsapp::ConversationWindowService` considera a última mensagem recebida do mesmo contato, caixa e empresa, inclusive quando existem várias conversas. Notas, mensagens do agente, templates e eventos de chamada não abrem a janela. No limite exato de 24 horas, o texto livre fica bloqueado.

Novos webhooks usam o timestamp do provedor. Timestamp ausente, inválido ou excessivamente futuro não deve abrir a janela. Mensagens antigas já armazenadas continuam usando o `created_at` existente; não há importação retroativa do histórico da Meta.

`Whatsapp::OutgoingMessageGuard` valida a criação, a tentativa manual de reenvio e novamente o envio no worker. Valida aprovação no catálogo da caixa, idioma, permissão da equipe, habilitação interna e variáveis. Os dados canônicos do modelo vêm do catálogo, não do texto informado pelo navegador.

A interface usa o estado retornado pelo servidor, eventos existentes de mensagens/conversas e uma consulta de recuperação a cada 30 segundos enquanto a página está visível. O contador não depende do relógio civil do computador do operador. O envio do modelo não altera a permissão de texto livre.

As mensagens não confirmadas pelo provedor não são apresentadas pelo banner como modelo já enviado. O histórico administrativo distingue fila, enviado, entregue, lido e falhou. Horários de status representam o registro no JRC, não necessariamente o instante exato do evento no provedor. A auditoria é por mensagem; não é uma tabela imutável de cada tentativa.

## Catálogo, permissões e limites

O novo fluxo administrativo atende `Channel::Whatsapp`: Meta Cloud (`whatsapp_cloud`) e 360dialog (`default`). Twilio, e-mail, Instagram, webchat e canais API mantêm suas regras específicas existentes; a nova janela não é aplicada globalmente.

Agentes consultam os modelos de uma conversa autorizada. Apenas administrador da conta ou Super Admin pode sincronizar, alterar regras e consultar logs administrativos. Regras de equipe são revalidadas no backend. Sem equipes selecionadas, o modelo fica disponível para as equipes autorizadas da caixa; conversa sem equipe não acessa modelo restrito. Favoritos são definidos por modelo/caixa para as equipes autorizadas, não por usuário individual.

O processador compartilhado também respeita bloqueios internos. Chamadas sem contexto de conversa, como certos disparos de campanha legados, não podem usar modelos restritos por equipe; use um modelo não restrito para esse fluxo. As campanhas não receberam uma nova interface neste pacote. A elegibilidade de texto livre existente em Campanhas já utiliza o serviço central de janela.

O formulário suporta texto, cabeçalho de texto ou URL de imagem/vídeo/documento, rodapé e botões URL, telefone, resposta rápida e copiar código. Cabeçalhos e botões dinâmicos também exigem preenchimento. A prévia mostra texto, rodapé, rótulos dos botões e URL da mídia; não foi criado um novo upload de mídia. Formatos como carrossel, Flow, catálogo/produtos, localização e botões especiais não são oferecidos para envio pelo novo formulário; o administrador pode identificá-los como não suportados.

A sincronização Meta lê todas as páginas antes de substituir o cache. Falha preserva o catálogo anterior e a data do último sucesso. Resultado vazio válido limpa modelos removidos. A sincronização periódica existente foi mantida, com intervalo de novas tentativas para evitar priorizar continuamente uma caixa com falha. Uma alteração de aprovação ainda pode ocorrer no provedor entre duas sincronizações; nesse caso, a resposta do provedor é a confirmação final do envio.

Sugestões de modelo por assunto usando NICO, favoritos pessoais, integração com Broker e novos provedores permanecem evoluções futuras. Não há envio automático por IA neste pacote.

## Endpoints

Todos seguem o escopo existente de conta, com autenticação e autorização:

```text
GET   /api/v1/accounts/:account_id/conversations/:id/whatsapp_window
GET   /api/v1/accounts/:account_id/inboxes/:id/whatsapp_templates
POST  /api/v1/accounts/:account_id/inboxes/:id/refresh_whatsapp_templates
PATCH /api/v1/accounts/:account_id/inboxes/:id/update_whatsapp_template_rule
GET   /api/v1/accounts/:account_id/inboxes/:id/whatsapp_template_logs
```

Os endpoints administrativos das caixas também estão registrados no namespace Super Admin. O envio usa o endpoint existente de mensagens e continua sendo processado pelo worker.

## Testes executados nesta preparação

- Ruby 3.3.8: 41 testes, 123 assertions, zero falhas/erros. Os testes carregam os serviços de produção, mas usam doubles de ActiveSupport, persistência, filas e HTTP. Não são testes de integração Rails/PostgreSQL.
- Node 22.16.0: 17 testes aprovados dos helpers e propagação da Promise de envio. A versão do projeto continua sendo a definida nos seus arquivos originais.
- Sintaxe: 27 arquivos Ruby/Jbuilder e 16 scripts JavaScript, incluindo os novos testes.
- Vue 3.5.13: templates de nove componentes compilados no Chromium. Quatro componentes tiveram interações exercitadas em cinco cenários com APIs, componentes básicos e bibliotecas de formulário simulados. Isso não equivale ao build Vite completo ou ao sistema integrado.
- ZIP: integridade e comparação de arquivos contra a base; manifesto com hashes.

Comandos independentes, executados na raiz do projeto:

```sh
ruby scripts/qa/whatsapp24h/services_test.rb
node --test scripts/qa/whatsapp24h/frontend_test.mjs
```

Esses testes não acessam banco, Redis nem WhatsApp. Não carregue `runtime.rb` dentro do Rails: ele contém doubles exclusivos da verificação isolada.

## Validações ainda necessárias no destino

O ambiente de preparação não possui as dependências completas da aplicação nem credenciais de um número real. Não foram executados o build Docker/Vite, a suíte Rails integrada, testes de concorrência/carga ou a comunicação real com Meta/360dialog.

Antes de produção, conclua a compilação na infraestrutura existente e valide autenticação, perfil de agente/admin/Super Admin, isolamento entre contas, sincronização, envio e recebimento reais, notas internas, novas conversas, campanhas e os demais canais. Preserve o backup para rollback. Sem migrations novas, o retorno do código à imagem anterior não requer desfazer schema; os metadados adicionados não são apagados automaticamente.
