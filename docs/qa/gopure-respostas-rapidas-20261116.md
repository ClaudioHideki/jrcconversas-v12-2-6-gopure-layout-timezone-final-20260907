# GoPure — Respostas rápidas contextuais com anexo

Data: 2026-11-16. Estado: implementação e validações locais concluídas; build de produção, CI e publicação pendentes.

## Diagnóstico e proveniência

O catálogo nativo guardava texto e atalho. O editor já possuía Liquid, ProseMirror, upload, assinatura, áudio e envio por MessageBuilder, mas não havia revisão contextual com arquivo nem intenção persistente de envio rápido.

A implementação parte da última atualização funcional remota conferida: `599b2f41e30570881432daebc3df2e9b70b0a366`, branch publicada `codex/gopure-crm-menus-20261109`. Um fetch explícito de todas as heads confirmou os 25 refs remotos; não apareceu atualização funcional posterior dessa linha. O checkpoint de exclusão administrativa `d9e17573de985d5b647677139c310b7c71556e92` pertence à ancestralidade preservada.

Branch deste incremento: `codex/gopure-respostas-rapidas-20261116`. Referência funcional LAB2: `5c3fb7f700d7bb685f17292f59b873df14ddf34d`. Foram selecionados os comportamentos de respostas rápidas; Central de Aprovações e outros módulos LAB2 não foram importados. A governança documental de `f21e9dd7cefab1c6c32ec36134950d96fbaa40cf` foi incorporada por 14 caminhos documentais explícitos, sem substituir a árvore funcional pela base anterior desse commit.

## Comportamento entregue

- Botão próximo à assinatura e atalho `/` abrem a mesma revisão; selecionar um modelo não envia mensagem.
- Busca por atalho/conteúdo, prévia editável, imagem e identificação de documento; inserção de texto formatado e arquivo pelo editor/anexador nativos.
- Criação e edição permitem selecionar, visualizar, substituir e remover um anexo por modelo. O botão de salvar modelo diz **Salvar resposta**, distinguindo-o de **Enviar agora**.
- Os aliases usam contato selecionado, usuário autenticado, empresa autorizada no Cadastro Mestre, cidade/região cadastradas, atributo contextual `produto_servico` e data no timezone da conta. Ausências permanecem para revisão manual.
- Modelos Liquid antigos continuam resolvidos pelos drops existentes. Expressões remanescentes precisam de revisão manual antes de inserir/enviar, para impedir uma segunda execução de expressões introduzidas pelos dados do contato.
- Enviar agora pede confirmação de destinatário, canal, texto final e arquivo. A resposta da interface confirma a criação na fila nativa; não equivale a entrega pelo provedor.
- Troca de conta, conversa ou autoridade invalida a prévia. Durante a revisão, atalhos de envio, colagem e arrasto do compositor de fundo ficam protegidos.
- Falha ambígua de HTTP conserva a intenção e o conteúdo para repetição segura. Erro de arquivo não dispara envio apenas de texto.

## Arquitetura, arquivos e banco

| Grupo | Arquivos principais |
| --- | --- |
| Catálogo e API | `app/models/canned_response.rb`, `app/controllers/api/v1/accounts/canned_responses_controller.rb`, `config/routes.rb` |
| Contexto e entrega | `app/services/canned_responses/{preview,delivery,attachment_policy}.rb` |
| Revisão e editor | `QuickReplyPicker.vue`, `ReplyBox.vue`, `CannedResponse.vue`, `WootWriter/Editor.vue`, `WootWriter/ReplyBottomPanel.vue`, `fileUploadMixin.js` |
| Cadastro de modelos | `settings/canned/{AddCanned,EditCanned,Index,CannedFileInput}.vue` |
| Cliente e tradução | `api/cannedResponse.js`, `store/modules/cannedResponse.js`, `en/cannedMgmt.json`, `pt_BR/cannedMgmt.json` |
| Validação | Specs direcionados, `vitest.quickReplies.config.ts`, inclusão dos testes no workflow existente `build-ghcr.yml` |
| Decisão e evidências | ADR 0002, TASKS, ROADMAP e este relatório |

Os nomes de componentes são relativos à estrutura existente em `app/javascript/dashboard`. Não houve migration, nova tabela ou alteração do schema. O arquivo usa Active Storage; a intenção e seu digest usam o JSONB existente `messages.additional_attributes.quick_reply`.

A entrega serializa a transação pelo lock da conversa e do modelo, verifica a intenção persistida e chama `Messages::MessageBuilder`. Mantém callbacks, jobs e histórico nativos. A mensagem recebe cópia independente do arquivo; remover ou substituir o modelo não apaga o anexo da mensagem já enviada.

## Permissões e integridade

As rotas de prévia, arquivo e entrega usam autenticação e escopo da conta. A conversa exige a política nativa de visualização; o acesso à empresa usa DirectoryPolicy e CorporateCoverage. O vendedor vem do usuário autenticado, mesmo quando outro usuário é responsável pela conversa.

O download do catálogo é autenticado e privado, vinculado à revisão e ao identificador do anexo, sem signed ID público e sem cache compartilhado. MIME, tamanho, arquivo não vazio e integridade do armazenamento são verificados. Liquid tem limites de expansão. A entrega revalida ator, contexto, revisão, arquivo, janela nativa do canal e confirmação explícita.

## Limitações por canal

A instalação mantém seu teto de upload (padrão 40 MB); também vale o menor teto do canal. A política acompanha os formatos já permitidos pelo editor para imagens e documentos.

| Canal | Arquivo no envio direto |
| --- | --- |
| WhatsApp | JPEG/PNG até 5 MB; documentos nativos até 100 MB, limitado pelo teto da instalação. Janela nativa de atendimento obrigatória. |
| Twilio WhatsApp | JPEG/PNG/PDF até 5 MB. |
| Twilio SMS | JPEG/PNG e documentos nativos até 5 MB. |
| Facebook | JPEG/PNG/GIF até 8 MB; documentos até 25 MB. |
| LINE | JPEG/PNG até 10 MB. |
| API, Web, e-mail, Telegram e SMS | Formatos de imagem/documento já autorizados e teto da instalação. A aceitação local não substitui os limites finais do provedor. |
| Instagram e TikTok | Texto com mídia na mesma entrega direta é bloqueado; oferecer inserção no editor para o fluxo nativo. |
| Outros canais | Arquivo no envio direto não é habilitado sem regra nativa conhecida. |

Os limites nativos de texto também são aplicados, incluindo 4096 caracteres WhatsApp/Telegram, 1600 Twilio WhatsApp e 320 SMS/Twilio SMS, medidos como no editor. Não houve envio externo para homologar provedores neste incremento.

## Testes e evidências

| Validação | Resultado |
| --- | --- |
| Backend e regressões nativas | **119 exemplos, 0 falhas** |
| Frontend, editor e regressões | **186 testes, 13 arquivos, 0 falhas** |
| Navegador real + Rails/PostgreSQL isolados | **23 verificações aprovadas, sem exceções de runtime nos roteiros aprovados** |
| RuboCop | **9 arquivos, nenhuma infração** |
| ESLint | **0 erros**, 1 aviso preexistente de chave dinâmica no tratamento de erro de áudio do ReplyBox |
| Preservação | Nenhum diff nos diretórios CRM, Cadastro Mestre, contatos, serviços/modelos JRC CRM, banco ou Docker/Compose |
| Build de produção e CI completa | **Pendentes**, não declarar aprovação integral de release |

Backend executado pelo wrapper nativo `scripts/nico-specs.rb`, com os specs de catálogo, `canned_replies_workflow`, serviços `canned_responses`, WhatsApp, direct uploads, MessageBuilder e Attachment. Inclui duas conexões PostgreSQL concorrentes, confirmação, retry com mesmo digest, troca de contexto/ator, arquivo ausente/corrompido, formatos e tamanhos, janela WhatsApp, dados corporativos não autorizados e isolamento entre contas. A concorrência confirmou uma mensagem, um anexo e um SendReplyJob. Os jobs de provedores não foram executados.

Frontend reproduzível:

```sh
pnpm exec vitest run --config vitest.quickReplies.config.ts --maxWorkers=1 --minWorkers=1
```

A configuração direcionada evita duplicar versões Vue no cache compartilhado e inclui somente os 13 arquivos de regressão pertinentes. Não remove testes do workflow completo.

O navegador utilizou componentes reais, editor ProseMirror, formulários nativos, API Rails autenticada, armazenamento e banco sintéticos. Módulos de shell não relacionados foram fornecidos pelo fixture. Foram testados celular, desktop, temas claro/escuro, criação/substituição/remoção de arquivo, `/`, bloqueio do compositor de fundo, contexto autorizado, inserção, confirmação e isolamento.

No cenário de perda do HTTP após o commit real do Rails, a repetição retornou a mensagem persistida. Uma consulta independente somente de leitura confirmou **1 mensagem, 1 intenção e 1 anexo**, com arquivo independente do modelo. Os três checks finais conferiram Liquid legado, bloqueio de expressão remanescente e correção manual sem envio.

Os resultados resumidos estão em [results.json](assets/respostas-rapidas-20261116/results.json). Logs detalhados e fixtures privados de autenticação ficam exclusivamente em `.codex/qa`, ignorado pelo Git. Nenhuma credencial ou dado real de cliente foi incluído nas evidências versionadas.

### Interface

[Prévia desktop](assets/respostas-rapidas-20261116/desktop.png) · [Celular, tema escuro](assets/respostas-rapidas-20261116/mobile-dark.png) · [Confirmação de envio](assets/respostas-rapidas-20261116/confirmacao.png) · [Cadastro com anexo](assets/respostas-rapidas-20261116/cadastro-anexo.png).

## Preservação e pendências

A base mantém telefone/DDI, Cadastro Mestre, CRM, indicadores, menus compactos, Kanban, etapas, filtros, propostas, versionamento, PDFs, aprovação e exclusão administrativa de pedidos, Campanhas e demais módulos existentes. A verificação de ancestralidade e o diff confirmam que esses fontes não foram substituídos; os testes direcionados não representam uma nova execução de todas as suítes desses módulos.

O ambiente local está com aproximadamente 2 GB de disco disponível e passou por pressão de memória/disco durante o QA. O build completo Vite de produção não foi executado nesse ambiente. A compilação Vite usada no navegador comprova os componentes exercitados, mas não substitui o build final. Permanecem avisos da base Browserslist desatualizada e sourcemaps de dependências; dependências compartilhadas não foram alteradas.

Somente dados sintéticos foram criados/excluídos no banco de QA dedicado. Nenhum pedido real foi excluído, nenhuma mensagem real foi enviada, nenhuma migration foi executada em produção e nenhum Compose foi alterado. Não houve push, nova imagem Docker, deploy ou exclusão de imagens/backups.

## Futura publicação

1. Obter autorização específica para enviar esta branch e publicar a imagem deste incremento.
2. Conferir novos refs remotos, ancestralidade e estado local; preservar alterações concorrentes e registrar o SHA candidato.
3. Executar a CI completa nesse SHA, incluindo build Vite, backend, CRM, Cadastro Mestre, Campanhas, Projetos, runtime e verificações finais. Os testes de respostas rápidas já foram adicionados ao workflow sem retirar etapas existentes.
4. Se algum gate falhar, corrigir a causa e repetir a CI antes da publicação.
5. Somente com todos os gates aprovados, publicar tag inédita e alias por SHA; verificar digest e integridade, preservando imagens anteriores.
6. Entregar SHA, link da CI, tag e digest. Instalação no Dokploy depende de autorização separada; não realizar deploy automático.
