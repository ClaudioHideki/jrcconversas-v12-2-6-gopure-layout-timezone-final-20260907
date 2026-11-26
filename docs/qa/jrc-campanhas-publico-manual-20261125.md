# JRC Campanhas — Público manual na primeira criação

Base preservada: `bf56af16adae9092b2415e96a563c08791f4ed4f`.
Branch isolada: `codex/jrc-campanhas-publico-manual-20261125`.

## Problema e reprodução

O teste de frontend reproduziu a primeira criação com 511 contatos: desmarcar todos, selecionar quatro, avançar e escolher o remetente. Antes da correção, a seleção mudava de include/quatro chaves para exclude/nenhuma chave, incluindo todos. A causa está no watcher de origem, cuja assinatura incluía a caixa de envio. O mesmo evento não ocorria ao editar uma campanha cuja caixa já estava preenchida.

## Correção

Separação de origem/remetente, persistência da seleção e confirmação da prévia, proteção de respostas assíncronas antigas, revalidação do botão Próximo, conferência de divergência na gravação/revisão/aprovação e validação de pertencimento na fronteira de disparo. A fila continua usando exclusivamente o snapshot aprovado, sem resolver novamente Todos os contatos.

## Evidências locais

- Backend: 211 exemplos de serviços e requests de campanhas aprovados, sem falhas.
- Regressão com 511 consentimentos ativos: criar e reabrir; quatro IDs na revisão; aprovar; quatro registros e quatro jobs na fila; exatamente quatro chamadas interceptadas da API oficial, somente para os números selecionados; outros 507 ausentes. Consentimentos comparados antes/depois e preservados integralmente.
- Testes negativos: criação ampliada após prévia; atualização com remoção da confirmação; revisão/aprovação/lançamento divergentes; destinatário extra inserido na fila; seleção de outra conta; desmarcar todos. Nenhuma chamada ao provedor nos caminhos bloqueados.
- Selecionar todos, seleção individual, pesquisa e paginação mantêm a seleção em frontend e backend. Retorno de etapas, reabertura, respostas antigas e prévia vazia/indisponível são cobertos.
- Frontend: 202 testes aprovados em 25 arquivos; sete cenários novos de público manual, além das suítes Meta/Evolution, mídia, consentimentos e fluxo de aprovação. Seleção reaberta também é salva novamente via update, e o estado real do botão Próximo é conferido no DOM.
- Build Vite completo aprovado (modo test). Avisos de tamanho de chunks, Browserslist e asset de marca já existentes; sem erro de compilação.
- ESLint: zero erros e 34 avisos existentes. RuboCop dos seis arquivos Ruby executado; correções automáticas revisadas, sem supressões novas. Permanecem avisos de estilo/complexidade no código existente e nas expectativas extensas dos testes de integração. A classe nova de confirmação não apresenta avisos.
- Regressão backend repetida após a revisão final: 211 exemplos, zero falhas.

Logs operacionais locais ficam em `.codex/qa/`, sem segredos ou dados de clientes no Git. O banco dedicado é `jrc_campaign_audience_20261125_test`; Redis de teste isolado. Não há envio real, deploy, acesso ao banco produtivo, alteração de Compose ou nova migration.

## Limites de implantação

Este incremento não foi publicado nem implantado. A imagem anterior permanece preservada. Campanhas já gravadas com público errado precisam ser revisadas explicitamente: a intenção manual perdida não deve ser inferida a partir dos consentimentos. Consentimento ativo não equivale à seleção de destinatário para uma campanha.

Decisão: [ADR 0006](../adr/0006-campanhas-selecao-manual-confirmada.md).
