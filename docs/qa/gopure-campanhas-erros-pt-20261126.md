# GoPure — Tradução dos erros de campanhas

Base: `4e5d26f7989e7b2703459ff230f5c5e01dbfd741`.
Branch: `codex/gopure-campanhas-erros-pt-20261126`.

## Alterações

ReportService acrescenta error_code usando o evento failed mais recente com código, correlacionado por inbox/external_id do delivery e conta da campanha. Consulta em lote por página, sem N+1 de eventos. Não altera error_message nem nenhum registro histórico. A interface usa o código confirmado para explicações em português dos erros 131049 e 131026, exibe o código e preserva a evidência original em Detalhes técnicos recolhidos.

Históricos sem código são reconhecidos apenas pelos dois títulos exatos conhecidos, normalizando maiúsculas, espaços e ponto final. Código desconhecido prevalece sobre um título conhecido: usa mensagem genérica em português, sem atribuir causa/código não confirmado. O texto original continua disponível. API/CSV mantêm o original para diagnóstico.

## Validação

- Frontend: 217 testes aprovados em 27 arquivos; sete casos focados do relatório passaram. Cobrem preferência pelo código, títulos históricos, erro desconhecido, detalhes originais e atualização dos recibos.
- Lint frontend: zero erros, oito avisos de regras existentes.
- Backend: 232 exemplos aprovados; após a formatação final, 12 exemplos de exclusão/recibos/erros aprovados novamente. Inclui consulta histórica dos dois códigos e isolamento contra evento de outra conta, preservando atributos originais.
- Build Vite test aprovado em 2m41s. Hooks normais lint-staged/RuboCop executados no checkpoint sem bypass; avisos legados registrados localmente.
- Ambiente dedicado sintético: jrc_campaign_errors_20261126_test, Redis DB 12. Comando de diagnóstico somente de leitura entregue ao usuário, que confirmou os códigos no Dokploy. Nenhum payload privado de produção foi gravado no repositório.

## Limites

Sem envio real, reenvio automático, alteração de bloqueios/consentimentos ou liberação de limite Meta. Sem migration nova, Compose/workflow alterado, push, CI remota, publicação de imagem ou deploy neste incremento. Os códigos confirmam a classificação dos dois erros; 131026 não revela sozinho a causa individual da impossibilidade de entrega.

[ADR 0010](../adr/0010-campanhas-erros-traduzidos.md).
