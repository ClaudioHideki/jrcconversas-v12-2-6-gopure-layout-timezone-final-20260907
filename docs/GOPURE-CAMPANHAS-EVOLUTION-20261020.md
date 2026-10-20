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

Os testes cobrem envio simulado, confirmação real pelo ID, ausência de ID, ACKs, timeout, rejeição, duplicidade, queda de worker, limites, consentimento e revogação, Account, histórico, mídias, janela e pausa/cancelamento no preflight. Há testes Vue para a confirmação do operador, idempotência e resultado desconhecido, além da regressão existente de CRM/NICO, financeiro, PDFs e WhatsApp oficial.

O workflow manual `build-ghcr.yml` executa a validação antes do build. A opção `publish` é falsa por padrão. Quando autorizada e selecionada, constrói a imagem de produção, inicia Rails e Sidekiq contra PostgreSQL e Redis exclusivos de CI, verifica HTTP e processos, e somente então publica as mesmas camadas testadas. Não publica `latest` e não executa deploy.

O smoke test identificou um falso negativo no health check de PostgreSQL quando a conexão ainda não havia sido inicializada. O endpoint verifica a conexão antes de consultar sua atividade; um teste de regressão reproduz a conexão fria e exige o resultado saudável com o banco disponível.

O relatório final deve informar os resultados efetivamente obtidos, SHA, digest e eventuais impedimentos. Testes com mocks e inicialização da imagem não comprovam homologação da instância real, suas credenciais, persistência de ACKs ou configuração de espelhamento no Dokploy. A consulta de status depende de a Evolution persistir mensagens e atualizações; se isso não ocorrer, a entrega permanece não confirmada. O provedor também pode espelhar mensagens de forma assíncrona; duplicatas de registro precisam ser verificadas no teste real antes da liberação operacional.
