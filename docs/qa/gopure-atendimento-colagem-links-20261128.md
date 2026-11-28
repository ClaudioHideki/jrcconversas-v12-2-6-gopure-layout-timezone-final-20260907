# QA local — URLs completas na colagem do atendimento

Data: 28/11/2026. Base: `c6004fd3bec3f3687895a0c06481cb69a188b49e`.
Branch: `codex/gopure-atendimento-colagem-links-20261128`.

## Alteração

Editor.vue passa HTML colado pelo helper editorPasteHelper apenas quando o schema do canal não tem marca link. Âncoras textuais HTTP(S) tornam-se o endereço de destino como texto; demais fragmentos conservam o fluxo atual. A seleção de schema por canal já existente é a fonte da decisão. FullEditor (rich text) não foi alterado.

## Validação

- 15 verificações isoladas com o editor nativo ProseMirror e helper, em fixture ignorada no Git (`.codex/qa/paste-links.spec.js`).
- WhatsApp e Channel::Api: evento de paste com texto+HTML e título; texto exibido e conteúdo emitido iguais à URL completa, incluindo session_id sintético, múltiplos parâmetros, codificação e #carrinho.
- E-mail e nota privada: título e atributo href preservados como hiperlink.
- Texto em torno de mais de um link, parágrafos e negrito mantidos.
- Destinos com porta explícita, parâmetros repetidos/vazios, caracteres codificados e fragmento mantidos sem normalização por URL.toString.
- Texto simples/colar sem formatação, HTML sem link, destino relativo, mailto, protocolo não-web e imagem vinculada não transformados.
- Colagem com arquivo continua usando o texto simples acompanhante, e editor desabilitado conserva o rascunho.
- jsdom não fornece geometria Range: fixture define somente os métodos necessários para a rolagem da seleção colada. Sem alteração de produção para contornar o ambiente de teste.
- ESLint dos dois arquivos funcionais: aprovado.
- Suíte existente de atendimento/respostas rápidas (`vitest.quickReplies.config.ts`): **186 testes aprovados em 13 arquivos** (editor, anexos, áudio, revisão/inserção de respostas rápidas, assinatura e helpers).
- Build Vite (`--mode test`): **aprovado em 2m35s**. Avisos existentes de Browserslist, sourcemap da dependência ProseMirror, asset de marca e tamanho/importação de chunks não causaram falhas.

## Preservação e limites

Nenhuma alteração em arquivos de campanhas, backend, banco/migrations, dependências, Docker ou workflow. Não alterados envio, assinatura, resposta rápida, anexos, macros ou configuração de provedor. Apenas o texto colado em schema sem suporte a hyperlink recebe o destino HTTP(S).

Não se abriu o carrinho informado pelo usuário. O endereço real e seu identificador de sessão não foram copiados para fixtures, logs ou Git. Sem dados de produção, envio real, CI remota, imagem publicada ou deploy. Se a área de transferência não contiver o destino (somente título), não há recuperação por adivinhação; o usuário precisa copiar o endereço completo.
