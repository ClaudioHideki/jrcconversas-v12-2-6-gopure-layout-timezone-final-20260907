# JRC Campanhas — auditoria e candidata de homologação

## Etapa A — base e fronteiras

- Base publicada preservada: `35c752d8cae6fa888a083b0740d82dd6d1ad8ee4`.
- Branch dedicada: `codex/jrc-campanhas-meta-midia-timezone-20261125`.
- Remoto: `ClaudioHideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907`.
- Checkout anterior limpo. Main e demais branches não são alvos desta tarefa.
- Autorização: push da branch e CI; sem publicação GHCR, merge, deploy, mudanças de credenciais ou dados de produção. Nenhum destinatário real foi autorizado para teste.

## Causas confirmadas por leitura do fluxo

1. `ScheduleWindow` converte para o fuso global e usa `Time.zone.parse`. Retorna o instante original após 14 tentativas, permitindo falha aberta em configuração inválida. Meta e Broker não repetem a checagem que Evolution realiza na fronteira do envio.
2. `TestMessageService` no caminho oficial chama o provider sem criar `TestDelivery`, sem exigir confirmação/idempotência. O WAMID retornado não comprova entrega. Evolution/Broker já têm rastreamento próprio, a preservar.
3. `IncomingMessageBaseService#process_statuses` lê somente o primeiro evento. `StatusTrackerService` procura apenas `Delivery` por ID global; não recebe a caixa e não rastreia testes nem eventos antecipados.
4. O assistente configura apenas variáveis do corpo. `parseTemplateParams` transforma JSON inválido em `{}` silenciosamente. Não há montagem visual do cabeçalho de mídia e a prévia apresenta apenas o corpo.
5. A tabela de público passa opções como segundo argumento de `audiencePreview`, mas o cliente HTTP recebe apenas o primeiro. O backend exige `include_recipients` fora de `campaign`, logo os contadores podem chegar sem os registros.
6. A prévia sem remetente usa `list_rejection_reason`, enquanto o envio oficial exige consentimento positivo. As regras da finalidade também diferem entre conectores.
7. Já existem paginação completa, substituição atômica do catálogo, scheduler e armazenamento de erros em `TemplateSyncService`; não recriar. Auditar concorrência e expor atualização no módulo de campanhas.
8. O provider usa v13.0/v14.0/v24.0 em caminhos distintos. Versão não é causa comprovada da não entrega relatada. Consultar documentação oficial antes de centralizar.

## Hipóteses e limitações

- Não foi provada a causa do erro Meta `132012` nos payloads reais nem da não entrega de um WAMID aceito. Não há logs produtivos sanitizados nesta tarefa.
- Não alterar registros de campanhas existentes nem reagendar jobs automaticamente. Uma alteração de janela exige revisão e aprovação humana.
- A candidata não equivale a homologação externa. Recebimento no celular, texto e botões, webhooks reais e credenciais de teste continuam dependências externas.

## Plano de checkpoints

A: auditoria; B: contrato de templates, mídia e prévia; C: testes Meta e status; D: fuso operacional; E: catálogo, público e consentimentos; F: segurança/regressão; G: CI e imagem candidata sem publicação. Registrar resultados reais em cada etapa.

## Etapa B — templates e mídia

- Contrato compartilhado entre teste e campanha, campos visuais de cabeçalho/corpo e URL dinâmica, bloqueio de componentes incompatíveis e JSON inválido.
- Recuperação automática de `example.header_handle` somente do catálogo aprovado da caixa autorizada, cache por conta/caixa/template e armazenamento permanente da aplicação. Exemplo expirado solicita importação manual; nunca representa sucesso fictício.
- Importação HTTPS pelo SafeFetch, verificação de conteúdo real, limites Meta, decodificação de imagens e rejeição de conteúdo ativo conhecido em PDF. Não equivale a antivírus universal; arquivo não é executado no servidor.
- Prévia de mídia, cabeçalho, corpo, rodapé e botões; parâmetros ausentes bloqueiam envio. IDs de arquivo preservados no serializer.
- Testes locais: 17 exemplos backend e 21 frontend aprovados. Fixture do fluxo oficial passou a fornecer um template realmente aprovado em vez de um nome inexistente.
- Caso de fuso reproduzido antes da correção: seis falhas esperadas em sete testes; o legado retorna 26/11 às 08h UTC para 25/11 às 19h21 UTC.
- Prettier de componentes de campanhas usa whitespace ignore para compatibilizar a formatação com o autofix Vue dos hooks; nenhuma regra foi desabilitada.
- Nova migration aditiva para chave de cache de mídia. Aplicada somente no banco sintético.

## Etapas C–F — rastreamento, janela e isolamento

- Testes individuais oficiais persistem pedido, usuário, caixa, destinatário, template/idioma, referência de mídia, idempotência, WAMID e timestamps. HTTP aceito não é entrega; falha e resultado desconhecido não geram reenvio automático.
- Webhooks percorrem os status e os envelopes, correlacionam por caixa e WAMID e retêm eventos antecipados para reaplicação idempotente sem envio. Conversas normais mantêm seus recibos e o lookup fica limitado à caixa.
- Fuso IANA explícito em `sending_window.timezone`, UTC no banco e nos instantes Sidekiq. Sem alteração global de Rails ou deslocamento fixo. Janelas antigas sem fuso continuam UTC até avaliação/autorização; o script `scripts/qa/campaigns/timezone_audit.rb` apenas consulta as campanhas ativas da conta explicitamente informada.
- Janela revalidada no job e na fronteira HTTP. Recorrência usa calendário no fuso operacional; retomada, follow-up, exportação e relatório seguem o mesmo fuso. A ponte Broker também verifica a janela antes do webhook nativo.
- Sincronização reaproveita paginação e cache existentes e acrescenta claim concorrente por caixa. Atualização manual exibe totais, aprovações, data e erro; tokens/webhooks não são alterados.
- Público paginado e contadores usam a mesma seleção. Prévia oficial exige finalidade `whatsapp_campaigns`, como o envio; lista QR mantém sua regra existente, sem fabricar consentimentos. Registros históricos sem finalidade não são promovidos automaticamente.
- A API de mensagens, mídia e catálogo foi centralizada em `WHATSAPP_CLOUD_API_VERSION`, padrão v24.0. Voz mantém o caminho v22.0 separado. Fontes oficiais consultadas: [versões Graph](https://developers.facebook.com/docs/graph-api/changelog/versions/), [mídia](https://developers.facebook.com/documentation/business-messaging/whatsapp/business-phone-numbers/media), [webhooks](https://developers.facebook.com/documentation/business-messaging/whatsapp/webhooks/reference/messages), [coleção oficial Meta](https://www.postman.com/meta/whatsapp-business-platform/request/2qbotrb/send-message-template-media).
- Regressão intermediária: 284 exemplos backend e 190 testes frontend sem falhas. Fixtures de envio usam janelas explicitamente abertas; o teste de resposta localiza o WAMID, preservando a ordenação por timestamp real do provedor.
- Browser com APIs simuladas: importação automática, substituição por upload, validação sem envio, confirmação do teste, aceito sem entrega fictícia, WAMID, histórico, tabela com cinco linhas, JSON inválido bloqueado, temas claro/escuro e viewport 390×844 sem overflow horizontal. Capturas em `docs/qa/campanhas-20261125/`. Nenhum teste visual usou um canal ou celular real.
- O teste visual revelou painéis de fundo fixo ilegíveis no tema escuro: convertidos para as classes semânticas Tailwind existentes. Rótulo oficial corrigido para Meta e WAMID exibido, preservando os rótulos Evolution/Broker nas respectivas caixas.
- Novas migrations são aditivas (tracking de testes e eventos) e de renomeação preservadora do atributo reservado `errors`; somente o banco sintético foi migrado.

### Garantia de separação Meta / Evolution

Caixas `whatsapp_cloud` entram no `Channel::Whatsapp` e no `WhatsappCloudService`. Rotas de campanha/teste/catálogo não consultam a configuração Evolution/Broker para essas caixas. URL alternativa no caminho de campanhas oficial é rejeitada antes do envio, sem fallback. Caixa Evolution é `Channel::Api`, depende exclusivamente da sua configuração explícita e não pode usar templates Meta. O rastreador oficial rejeita caixas API. Testes de isolamento verificam POST oficial com imagem em teste e campanha, ausência de consulta/chamada Evolution, rejeição de URL alternativa, rastreamento por caixa e recusa de template Meta na caixa API. O endpoint oficial também é validado no provider Cloud usado pelo catálogo nativo; nenhuma alteração é aplicada ao transporte Evolution.

Regressão local final antes dos hooks: 285 exemplos backend e 192 testes frontend aprovados, mais o teste explícito adicional de rótulo Meta (12 casos do arquivo, todos aprovados). A invocação inicial do frontend com a configuração genérica falhou na resolução local de fake-indexeddb; a configuração dedicada usada pela CI passou integralmente. ESLint: zero erros; 53 avisos de i18n, principalmente chaves dinâmicas e pontuação, sem desativar regras. RuboCop executado de verdade pelo hook, com correções seguras revisadas e avisos de complexidade/estilo remanescentes; não foi utilizado bypass. A CI continua pendente de envio do checkpoint.

## Pendências para homologação externa

Não foi efetuado envio real nem confirmado recebimento em celular. Precisam de autorização específica e ambiente Meta de teste: destinatário, evidência de consentimento, recebimento de imagem/texto/botões, WAMID real e webhook de entrega/leitura. O incidente produtivo de não entrega não pode ser atribuído exclusivamente ao formato ou à versão da API sem essas evidências.

## Imagem candidata e operação

CI autorizada e publicação GHCR proibida nesta etapa. O workflow recebe `publish=false` e uma tag candidata nova: executa a CI, constrói a imagem, testa Rails/Sidekiq em banco isolado e armazena um arquivo Docker comprimido como artefato de CI por três dias, com checksum e identificação do commit. Não efetua login/push GHCR. Candidata não é homologação nem atualização produtiva.

Atualização futura: somente após aceite/autorização, conferir SHA/checksum, carregar a candidata e executar o procedimento aprovado do ambiente, com as migrations pendentes avaliadas. Não retomar campanhas legadas automaticamente. Rollback deve usar a imagem anterior preservada e avaliar a compatibilidade das colunas aditivas; não apagar histórico de envio ou executar reversão destrutiva de banco.

## Checkpoints locais consolidados

- C–E: `04bd0bee` — testes oficiais persistentes, status/webhooks, janela IANA, catálogo e isolamento de transportes.
- F: `59382b17` — interface, histórico, rótulos e teste de não regressão Meta/Evolution.
- Os 55 arquivos Ruby passaram pelos hooks reais, sem diferenças entre fonte local e ambiente sintético. Métricas de complexidade e avisos de estilo permanecem documentados; não houve bypass ou supressão de regras.
- O teste adicional de rótulo confirma Meta/WAMID sem rótulo Evolution, além dos testes Evolution/Broker existentes.

O teste de isolamento foi ampliado para seis casos aprovados: uma rejeição HTTP 400 da Meta permanece falha oficial, sem consulta ou chamada à Evolution/Broker. A CI preliminar foi cancelada para validar o checkpoint com esse caso explícito, sem gerar/publicar imagem parcial.

Rejeições imediatas agora persistem código/classificação permitidos e horário, sem corpo bruto nos logs de campanhas. O código 132012 recebe descrição segura de incompatibilidade de parâmetros; os demais recebem descrição genérica com código consultável. O tratamento nativo de mensagens comuns permanece intacto. Regressão adicional: 95 exemplos, zero falhas, incluindo Evolution, Cloud, testes oficiais e isolamento.
