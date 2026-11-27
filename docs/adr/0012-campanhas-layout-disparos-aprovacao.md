# ADR 0012 — Painel de disparos e revisão legível

Estado: implementação local em 27/11/2026.

## Contexto

O usuário aprovou o funcionamento das campanhas e pediu somente a apresentação do painel conforme a referência enviada, mantendo todas as ações, inclusive excluir. A revisão exibia parâmetros JSON, URLs longas e valores técnicos, gerando excesso de informação e rolagem horizontal.

## Decisão

- Indicadores com faixas de cor, quantidade em destaque e taxas sobre os envios do período, usando os dados de analytics existentes. As cores do funil seguem os indicadores.
- Distribuir falhas e campanhas em 3/9 colunas no desktop. Reduzir a largura mínima da tabela e reunir todas as ações no menu por campanha, com rótulos, navegação por teclado e posicionamento fora do contêiner rolável.
- Preservar exatamente os handlers e restrições existentes de revisar, iniciar, pausar, retomar, cancelar, editar, relatar, duplicar e excluir. Manter confirmação de exclusão e bloqueio para campanhas em execução/pausadas.
- Revisão com cabeçalho e rodapé fixos dentro do diálogo, conteúdo rolável, resumo em cartões, dias/modes legíveis, mensagens com mídia e conteúdo das definições Meta já presentes no snapshot e destinatários do mesmo snapshot.
- Dados técnicos permanecem disponíveis em detalhes recolhidos; não alterar parâmetros salvos, mensagens, público, digest, aprovação de 48 horas, validação de divergência, conectores, fila ou serviço de disparo.
- Usar componentes Vue e utilitários Tailwind existentes; nenhuma alteração em backend, migrations, dependências, Compose, workflows ou produção.

## Evidências e limites

[QA local](../qa/gopure-campanhas-layout-disparos-20261127.md). A conferência no navegador usa somente dados sintéticos e não chama transportes reais. Não houve publicação ou deploy neste incremento.
