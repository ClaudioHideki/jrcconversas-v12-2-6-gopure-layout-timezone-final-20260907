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
