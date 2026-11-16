# ADR 0002 — Respostas rápidas contextuais com anexo

- Estado: Aceita para implementação local; publicação e aceite operacional pendentes.
- Data: 2026-11-16.
- Solicitação: atualização do módulo nativo de Respostas Rápidas da GoPure.

## Contexto

A versão publicada `599b2f41e30570881432daebc3df2e9b70b0a366` possui Rails, Vue/ProseMirror, Liquid, Active Storage e MessageBuilder. O catálogo anterior guarda somente texto e atalho. A referência funcional LAB2 `5c3fb7f700d7bb685f17292f59b873df14ddf34d` também contém outros módulos, que não fazem parte desta atualização.

A branch documental `f21e9dd7cefab1c6c32ec36134950d96fbaa40cf` deriva de uma base anterior à publicação. Seus 14 arquivos documentais foram conferidos e incorporados por caminhos explícitos. O código GoPure publicado foi mantido como base; não foi substituído pela árvore dessa branch.

## Decisão

1. Estender CannedResponse e seu controlador nativos, mantendo as rotas e contratos anteriores de texto. Adicionar prévia, download autenticado e entrega com confirmação.
2. Usar `has_one_attached :file`, com um anexo por modelo, sem criar tabelas ou migrations. O nome/atalho continua sendo `short_code`.
3. Resolver Liquid com os drops nativos; os aliases usam o contato selecionado, usuário autenticado, timezone da conta e Cadastro Mestre autorizado. Ausências permanecem editáveis. Limitar expansão de templates para evitar consumo ilimitado.
4. Inserir o conteúdo revisado pelo ProseMirror e anexador existentes. `/` e o botão próximo à assinatura passam pela mesma revisão. Uma seleção não envia a mensagem.
5. Usar MessageBuilder para o envio confirmado, mantendo callbacks, histórico e jobs. Copiar o arquivo para o anexo da mensagem para preservar o histórico após alterações no modelo.
6. Persistir chave e digest em `messages.additional_attributes.quick_reply`. Serializar intenções com lock da conversa e do modelo; uma repetição retorna a mensagem existente antes de validar uma revisão posterior do modelo. Não introduzir um segundo transporte.
7. Conferir destinatário/caixa novamente no servidor. Validar autorização da conta e conversa, revisão do arquivo, formatos, tamanhos e janela nativa de atendimento. Impedir envio direto combinado nos canais que exigem mensagens separadas.
8. Usar PT-BR conforme a solicitação explícita, mantendo também as chaves em inglês. Não portar Central de Aprovações, proteções de Service Desk ausentes na GoPure, nem outros módulos LAB2.

## Consequências

O catálogo continua compartilhado entre membros autorizados da mesma conta. A prévia não concede acesso a outras conversas. O download do modelo exige autenticação, não publica signed IDs e não admite cache público. Arquivos enviados são independentes do modelo. Não há alteração no schema, Compose ou dados de produção.

A validação usa exclusivamente contas e mensagens sintéticas, canais API locais e jobs de teste. Aprovação de testes locais não equivale à CI completa, publicação, entrega por provedor ou implantação. Ver [relatório de QA](../qa/gopure-respostas-rapidas-20261116.md).
