# GoPure: Campanhas e Evolution Demo

## Base verificada

Repositório: `ClaudioHideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907`.

Branch de origem: `crm-comercial-r2-20260922`, SHA `d4c7167ff2e7b44f5ca732a6183e04256d149d33`. Todas as branches foram consultadas por fetch; a `main` estava atrás dessa base. A branch divergente mais antiga `fix/nico-autonomia-workflow` não foi misturada com o CRM r3.

A imagem informada pelo operador é `4.16.2-gopure-crm-comercial-20260923-r3` (o `v` final inicialmente informado foi corrigido pelo operador). Manifest GHCR: `sha256:d03cf02cb8ef4d099e119a78449d8fcf6b0fe15389054be1ec7732012ab12df2`. Sua label `org.opencontainers.image.revision` confirma o SHA acima. As cópias locais anteriores permanecem preservadas.

Branch desta implementação: `codex/gopure-campanhas-evolution-20261020`. A publicação candidata usa o pacote GHCR existente e a tag `gopure-campanhas-evolution-20261020`. O SHA e o digest finais devem ser conferidos no resultado do Actions e no manifest publicado; a existência deste documento não comprova publicação.

## Implementação

- Configuração explícita por Account e Inbox; caixas API genéricas permanecem inelegíveis. URL HTTPS, instância, número remetente, webhook, limites e nome da variável de credencial são validados. Nenhuma credencial vai ao metadata da interface.
- A API da instância existente é utilizada para texto, imagem, documento, vídeo e áudio. A integração não é reinstalada nem reconfigurada. Templates Meta continuam exclusivos das caixas oficiais; campanhas oficiais e Evolution devem ser separadas.
- Os anexos são baixados pelo JRC com a proteção SSRF já existente, MIME compatível e limite de 10 MB, e enviados em base64. A Evolution não recebe uma URL arbitrária para buscar na rede dela. A configuração global de rede privada do SafeFetch deve manter sua proteção padrão no ambiente.
- Antes do envio, uma consulta somente de leitura verifica que a instância está aberta e seu `ownerJid` corresponde ao remetente configurado. O destinatário vem do telefone normalizado, sem reutilizar o número remetente como destino.
- O contrato da Evolution 2.3.7 foi inspecionado no código disponível localmente: o webhook Chatwoot pode retornar `{ message: 'bot' }` após capturar uma falha. Esse HTTP 200 não é comprovação de envio. O adaptador exige `key.id`, `fromMe` e destino compatível na resposta de envio direto.
- Um ID externo representa aceitação da mensagem pelo provedor; não representa entrega ao aparelho. Consultas somente de leitura em `/chat/findMessages/:instance` reconhecem `SERVER_ACK`, `DELIVERY_ACK`, `READ`, `PLAYED` e `ERROR`. Ausência de confirmação permanece não confirmada. A consulta automática é limitada a 20 tentativas de um minuto; ela nunca reenvia a mensagem.
- Mensagens aceitas são registradas em Conversas com `source_id` `WAID:<id>`. O marcador interno impede um segundo envio pelo webhook da caixa API ou por `SendReplyJob`. Uma mensagem já espelhada pela Evolution com o mesmo ID é reutilizada.
- O claim de entrega é persistido antes do envio. Jobs repetidos não retomam claims `sending` ou `unknown`. Timeouts, HTTP 5xx, resposta sem ID ou destino divergente não causam reenvio automático. Recusas explícitas são registradas como falha.
- Campanhas e testes compartilham um bloqueio persistente por caixa, intervalo mínimo e limite diário de tentativas. Um claim externo pendente após queda do worker bloqueia novas tentativas. Falhas interrompem a campanha e exigem revisão operacional. Pausa e cancelamento durante o preflight não enviam a mensagem; retomadas e adiamentos respeitam a janela de envio.
- O teste individual exige confirmação explícita e chave de idempotência. O resultado e seu histórico podem ser consultados por administradores da mesma Account, sem novo envio. A interface diferencia aceitação de entrega e mostra resultados desconhecidos.
- A audiência mostra os motivos de inelegibilidade. Telefone, blacklist, bloqueio e consentimento são rechecados no limite do envio, inclusive para testes.

## Consentimento e homologação real

A migration adiciona a finalidade `purpose`, sem alterar evidências, autores ou datas históricas. Registros antigos ficam com finalidade não confirmada (`NULL`); a migration não presume que uma autorização antiga cobre campanhas ou testes pela Evolution. O fluxo oficial mantém sua política histórica. Para a Evolution, é obrigatório consentimento ativo com finalidade `whatsapp_campaigns`; novas autorizações registradas dentro do módulo Campanhas explicitam essa finalidade.

Não preencher a finalidade de registros antigos sem conferir a evidência e a cobertura da autorização. Não criar consentimento fictício para liberar o teste. Blacklists, bloqueios e revogações continuam prevalecendo.

O operador indicou um destinatário para homologação, condicionado ao consentimento da Account 2 e a nova autorização explícita antes do envio. Nenhum teste real, disparo para clientes, campanha ativa ou deploy de produção faz parte da validação automatizada. A chave da Evolution ainda precisa ser conferida de forma segura no Dokploy, em WhatsApp API → production → app-2 → Environment. Não presumir o nome da variável de origem nem copiá-la para código, Git ou logs.

## Configuração para implantação posterior

Por padrão, `JRC_CAMPAIGNS_EVOLUTION_CONNECTORS` é `[]`: nenhuma caixa API é habilitada automaticamente.

Após aprovação da implantação, aplicar o mesmo JSON em Rails e Sidekiq:

```json
[{"account_id":2,"inbox_id":8,"base_url":"https://wht-api.jrcws.cloud","instance":"WhatsApp_JRC_POC-b","sender_number":"551155580441","api_key_env":"JRC_CAMPAIGNS_EVOLUTION_DEMO_API_KEY","min_interval_seconds":60,"daily_limit":50}]
```

`JRC_CAMPAIGNS_EVOLUTION_DEMO_API_KEY` deve ser configurada pelo mecanismo de segredos do ambiente, com a chave efetiva autorizada da instância existente. O conector aceita nomes de variável no padrão `JRC_CAMPAIGNS_EVOLUTION_*_API_KEY`; o exemplo nomeia a nova referência usada pelo JRC, sem afirmar qual variável a instalação Evolution utiliza.

O intervalo não pode ser inferior a 60 segundos. O limite diário padrão é 50 tentativas e pode ser configurado entre 1 e 100. A contagem usa a data da aplicação e inclui campanhas e testes dessa caixa, mesmo entre workers diferentes. Mensagens normais enviadas pela interface Conversas não estão sob esse limitador. Limites baixos não eliminam o risco de bloqueio de uma integração não oficial.

Usar `deploy/gopure-campanhas-evolution.compose.override.yml` como complemento do Compose existente. Confirmar os nomes reais dos serviços; o exemplo usa `rails` e `sidekiq`. Definir `GOPURE_CAMPAIGNS_IMAGE` com a referência GHCR publicada e seu digest. Ambos os serviços devem usar exatamente a mesma imagem. Não alterar banco, volumes, URLs, configurações das demais integrações ou imagem do NICO Runtime.

## Ordem de atualização — depende de aprovação separada

1. Registrar a imagem/digest anterior, obter backup consistente do banco pelo procedimento existente e pausar campanhas durante a janela de atualização.
2. Conferir no GHCR que a imagem candidata tem a revisão Git validada. Preparar o Compose sem aplicá-lo automaticamente.
3. Com o novo código e os serviços de aplicação parados durante a manutenção, executar `bundle exec rails db:migrate` uma única vez no banco correto. Migration nova: `20261020120000_add_evolution_campaign_test_deliveries.rb`. Ela adiciona coluna, tabela de testes e índices; não remove dados.
4. Iniciar Rails e Sidekiq com a mesma imagem consolidada e a mesma configuração de conector. Conferir `/api`, logs e filas.
5. Na Account 2, conferir caixas 1 e 8, remetente da Demo, consentimentos e audiência. Conferir também Conversas, Cockpit, Contatos, CRM, e-mail, NICO e telefonia no ambiente.
6. Antes de qualquer teste real, verificar novamente a autorização do destinatário e solicitar ao operador sua aprovação explícita. Fazer apenas o teste individual aprovado, confirmar o ID externo e distinguir aceitação de ACK de entrega. Nenhuma campanha de produção deve ser ativada automaticamente.

## Falhas, retomada e rollback

Pausas normais preservam etapas pendentes. O comando Retomar reaproveita essas etapas com claim idempotente, intervalo e janela de envio.

Uma falha de provedor ou resultado desconhecido abre o bloqueio de segurança da caixa em `channel.additional_attributes.jrc_campaign_evolution_state`. Não limpar esse bloqueio automaticamente, não mudar entregas desconhecidas para `queued` e não reiniciar o mesmo envio. Conferir a Evolution e os registros locais, documentar a decisão e manter destinos com resultado desconhecido excluídos de novas campanhas. Somente após revisão humana dos claims pendentes é possível liberar o bloqueio operacional, preservando contagem diária e último horário. Claims desconhecidos permanecem sem reenvio automático.

Para rollback, pausar/cancelar as campanhas dessa versão, parar Sidekiq e Rails e restaurar em ambos a imagem anterior pelo digest registrado acima. Desabilitar o conector no ambiente (`[]`). Não executar rollback da migration, reset, drop ou remoção de volumes: a coluna e a tabela adicionais podem permanecer, preservando os históricos de teste. Retomar apenas os fluxos previamente homologados.

## Validação e limites

### Revisão r3: consentimento contínuo por destinatário

A tag `gopure-campanhas-evolution-20261020-r3` torna o **Consentimento contínuo para testes e campanhas** o cadastro principal na aba de consentimentos. O administrador registra uma vez a autorização real de cada destinatário, com evidência, origem e data, confirmando explicitamente que o escopo inclui mensagens recorrentes pelo WhatsApp desta conta. O consentimento permanece válido até revogação; não é consumido por testes ou campanhas. Isso não concede autorização global para telefones sem consentimento nem ativa campanhas automaticamente.

Registros históricos sem finalidade confirmada não são ampliados por migration. A ação **Registrar nova autorização para este telefone** exige nova evidência e confirmação do titular. Ela encerra o registro anterior e cria um consentimento vinculado por `supersedes_id`, na mesma transação e sob bloqueio da Account. Evidência, data, autor e finalidade originais permanecem no histórico. Falhas de validação desfazem toda a transação; um consentimento contínuo já ativo não é substituído por repetição da solicitação. Revogações repetidas preservam sua primeira data.

A migration adicional `20261020201000_add_campaign_consent_supersession.rb` adiciona somente a referência histórica nullable, seu índice único e a chave estrangeira para a própria tabela. Ela não preenche finalidade e não altera consentimentos existentes. O POST de consentimentos passa a exigir `operator_confirmed: true`; integrações administrativas devem enviar essa confirmação real. Recarregar a interface depois de atualizar Rails e Sidekiq.

Com consentimento contínuo ativo, o teste usa esse registro e preserva eventual autorização de teste único disponível. A opção de teste único e seus históricos permanecem numa seção opcional recolhida. Revogações, blacklist, bloqueios e limites operacionais continuam sendo verificados. Para iniciar uma campanha, os destinatários autorizados também precisam constar no público e estar selecionados.

O botão **Preparar novo teste**, após um envio aceito e o intervalo configurado, inicia uma nova solicitação intencional, inclusive para o mesmo conteúdo. Preparar não envia: ainda é necessário clicar em **Enviar teste** e confirmar remetente e destinatário. Repetir uma solicitação existente preserva a mesma chave idempotente. Resultados desconhecidos não habilitam esse botão; não há reenvio automático. Os dois botões de teste da Revisão usam o mesmo fluxo, mesmo com público de campanha zerado, e respeitam a espera entre testes.

Não há novas variáveis de ambiente nem alteração do NICO Runtime. Aplicar a nova migration com a imagem r3, usar a mesma imagem/digest em Rails e Sidekiq e atualizar a página. Para rollback desta revisão, restaurar `gopure-campanhas-evolution-20261020-r2@sha256:8fa45bc19a1244eac679dac5ba12e1052a1fa9c4bd45b79f90a7d22eabb7a51a` nos dois serviços. Preservar a coluna e todos os registros; não executar rollback destrutivo. Consentimentos contínuos explicitamente concedidos continuam ativos no código r2, que já reconhece essa finalidade.

### Revisão r2: autorização de um único teste

A tag `gopure-campanhas-evolution-20261020-r2` adiciona a seção **Autorizações de teste único** dentro da aba **Consentimentos para campanhas**. O administrador registra a caixa Evolution, o telefone do destinatário, a evidência da autorização e sua confirmação explícita. O registro guarda também a identidade do conector e o número remetente. Ele não cria nem altera consentimento para campanhas e não modifica evidências históricas sem finalidade confirmada.

Uma autorização disponível permite uma solicitação de teste nessa conta, caixa, destinatário e remetente. Ao criar a solicitação, o sistema consome a autorização na mesma transação, antes da chamada externa. Falha, rejeição, timeout ou queda do worker não a tornam reutilizável. Solicitações repetidas com a mesma chave retornam o histórico existente; uma chave nova exige outra autorização do titular. Blacklist, telefone, bloqueios e revogações são verificados antes do envio. O consentimento amplo já confirmado continua funcionando como antes.

A migration adicional `20261020193000_create_jrc_campaign_test_authorizations.rb` apenas cria a tabela e seus índices/chaves estrangeiras. Não altera o registro antigo de consentimento. Não há novas variáveis de ambiente. Aplicar a migration uma vez antes de iniciar Rails e Sidekiq com a imagem r2; ambos precisam usar a mesma imagem/digest. Não executar SQL para ampliar a finalidade do consentimento antigo.

Depois da atualização: registrar na nova seção a autorização real do titular com sua data e referência; voltar ao teste individual, selecionar a mesma caixa e destinatário, conferir o conteúdo e confirmar o único envio autorizado. O público da campanha pode continuar com zero aptos, pois essa autorização não habilita campanhas. Não ativar a campanha.

Para voltar da r2 à primeira imagem desta entrega, usar `gopure-campanhas-evolution-20261020@sha256:244742d7bd71c6a487438aa6354875cf02b6f0316bc28084616f576b94714bef` nos dois serviços. Manter a tabela nova e seus registros; a imagem anterior não utiliza essas autorizações. Não executar rollback destrutivo de migration.

Os testes cobrem envio simulado, confirmação real pelo ID, ausência de ID, ACKs, timeout, rejeição, duplicidade, queda de worker, limites, consentimento e revogação, Account, histórico, mídias, janela e pausa/cancelamento no preflight. Há testes Vue para a confirmação do operador, idempotência e resultado desconhecido, além da regressão existente de CRM/NICO, financeiro, PDFs e WhatsApp oficial.

O workflow manual `build-ghcr.yml` executa a validação antes do build. A opção `publish` é falsa por padrão. Quando autorizada e selecionada, constrói a imagem de produção, inicia Rails e Sidekiq contra PostgreSQL e Redis exclusivos de CI, verifica HTTP e processos, e somente então publica as mesmas camadas testadas. Não publica `latest` e não executa deploy.

O smoke test identificou um falso negativo no health check de PostgreSQL quando a conexão ainda não havia sido inicializada. O endpoint verifica a conexão antes de consultar sua atividade; um teste de regressão reproduz a conexão fria e exige o resultado saudável com o banco disponível.

O relatório final deve informar os resultados efetivamente obtidos, SHA, digest e eventuais impedimentos. Testes com mocks e inicialização da imagem não comprovam homologação da instância real, suas credenciais, persistência de ACKs ou configuração de espelhamento no Dokploy. A consulta de status depende de a Evolution persistir mensagens e atualizações; se isso não ocorrer, a entrega permanece não confirmada. O provedor também pode espelhar mensagens de forma assíncrona; duplicatas de registro precisam ser verificadas no teste real antes da liberação operacional.
