# Evidências locais e condições de publicação

Data: 2026-11-03. Estes resultados não comprovam implantação nem entrega WhatsApp.

- Broker: correção inicial observou cinco testes RED; revisão independente acrescentou um sexto RED para grafo explícito sem ID de grupo. GREEN final: 41 testes em quatro arquivos de importação, incluindo credenciais e recursos; typecheck sem erros.
- Export OIA/Teste original conferido apenas localmente: 83 nós, 106 conexões, 44 saídas de menus e nenhum texto vazio; oito ações externas bloqueadas, sem equivalência declarada para o Bridge.
- Editor oficial gerado do Broker `13e8525a0103a00cada4864acba46a654cf9471b`, `sourceCommitted=true`, 216 entradas e inspeção sem achados. Teste do bundle anterior da mesma frente confirmou sete cenários sem requisições externas; o manifesto final deve ser conferido novamente com o SHA final.
- Conversas: rodada dirigida inicial 108/115; sete falhas em testes de composição de navegação foram corrigidas fornecendo o helper real e preservando a posição GoPure de Clientes. Regressores repetidos: 19/19. Menu de atendimento: falha anterior reproduzida e contrato atualizado para o componente atual; 2/2 após informar Account/tipo de destinatário e verificar a ação real.
- Revisão independente identificou import duplicado de Popover, SHA interno ausente no Dockerfile e fallback Typebot indevido. O compilador Vue reproduziu a duplicação e confirmou a correção; o Dockerfile agora valida GIT_SHA e a CI exige seu valor dentro da imagem; o sexto teste Typebot reproduziu e corrigiu o fallback. Nenhum outro achado acionável foi reportado no recorte revisado.
- Validador existente aprovou 435 fontes JS/JSON/Vue alterados e 297 timestamps, incluindo 26 migrations novas posteriores ao schema GoPure anterior. Gates de release/timestamp: 10/10. YAML dos workflows foi parseado e os três prerequisites da imagem confirmados.
- Compose HML validado por `docker compose ... config --quiet`, com placeholders, sem iniciar serviços. ESLint dirigido das resoluções de navegação/layout/atendimento passou após correção de formato e import.
- Suíte ampla Broker local inicial: 499 arquivos aprovados/5 com falhas; 3.919 testes aprovados, três falhas e quatro skips, além de duas suítes impedidas por preparação incompleta do ambiente. As causas foram Git no PATH, fonte upstream ainda não inicializada e OpenSSL ausente. Regressores após preparar Git/OpenSSL/submodules: 27/27 de auditoria de dados e 14/14 de socket/provider/upstream. A verificação PDF completa permanece dependente do gate Linux com histórico completo e ferramentas Poppler. Não apresentar a rodada local ampla como verde.
- Ruby e Docker daemon não estavam disponíveis no sandbox local. Os testes reais Rails/PostgreSQL/Sidekiq, a compilação da imagem e os testes do backend integrado são obrigatórios nos jobs GitHub, sem relaxar assertions ou desativar verificações.

## Publicação

Broker: workflow `images.yml`, branch HML, `publish=true`, `include_recovery=false`, componente `all`. Run iniciado: https://github.com/ClaudioHideki/BrokerJRCIA/actions/runs/41718380285. A conclusão e os digests devem ser conferidos; esta nota não declara publicação antecipadamente.

Conversas: workflow `build-ghcr.yml` do destino, branch HML. O build depende de `validate`, `commercial-flow` e `broker-and-import-integration`. A tag permitida é somente `ura-hml-sha-<SHA completo>`. O workflow confere label, SHA interno, plataforma e inicialização Rails/Sidekiq antes de publicar. Imagens anteriores não são sobrescritas.

O aceite final exige os artefatos e resultados dos runs do SHA da imagem. WhatsApp real, implantação HML, catálogo de destinos e comparação com a produção são etapas posteriores, não executadas por esses checks locais.
