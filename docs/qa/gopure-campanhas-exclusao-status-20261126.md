# GoPure — Exclusão de campanhas e status de leitura

Base: `6d528f9a19b1ada360a17733870ed9d1a07b25d1`.
Branch: `codex/gopure-campanhas-exclusao-status-20261126`.

## Implementação

A ação Excluir já existia no extremo direito de uma tabela larga; foi movida para junto do nome, com texto visível, confirmação explícita de perda do histórico e bloqueio de clique repetido. O endpoint permanece exclusivo de administradores da conta e confere execução/pausa sob lock, serializando a exclusão com o lançamento. Remove campanha e dependentes, preservando contatos e mensagens nativas.

O relatório exibia códigos brutos e carregava só ao abrir. A interface traduz todos os estados de destinatários, consulta a página atual a cada 15 segundos, permite atualizar manualmente, não sobrepõe consultas, conserva último resultado em erro e encerra o timer no fechamento. Fechar o relatório atualiza os indicadores do painel. Os códigos da API não mudam.

No agregador, um delivery posterior podia rebaixar o status do destinatário já lido para entregue, apesar de read_at permanecer preenchido. Agora preserva o estado de leitura/resposta e serializa agregação por destinatário. Os callbacks oficiais continuam isolados por inbox e chegam pela rota Meta existente; nenhuma dependência Evolution foi introduzida.

## Validação

- Frontend: 211 testes aprovados em 27 arquivos, incluindo tradução real das mensagens, atualização automática da mesma página, encerramento do timer, recuperação após falha e exclusão confirmada na coluna do nome.
- ESLint: zero erros, 17 avisos de regras existentes.
- Backend final: 226 exemplos, zero falhas. Inclui exclusão concluída preservando contato/mensagem, bloqueio de execução/pausa, agente/tenant incorreto, callbacks Meta pela entrada nativa após conclusão, evento atrasado e inbox de outra conta. Sem recibo de leitura, read_at permanece vazio e o relatório continua Entregue.
- Build Vite test aprovado em 2m50s. Hooks normais lint-staged/RuboCop no checkpoint, sem bypass; avisos legados permanecem.
- Banco sintético dedicado `jrc_campaign_status_20261126_test`, Redis DB 10. Sem dados reais, envio externo ou chamadas ao WhatsApp para gerar recibos.

## Limites reais

O screenshot não permite concluir se o WhatsApp enviou o evento de leitura do destinatário mencionado. Não foram consultados eventos/logs de produção; o estado desse caso específico não foi alterado nem declarado corrigido. Sem recibo de leitura recebido, o produto conserva Entregue e não fabrica Lida.

Sem migration nova, alteração de Compose/workflow, publicação de imagem, push, CI remota, deploy ou alteração de dados produtivos neste incremento. [ADR 0008](../adr/0008-campanhas-exclusao-relatorio-leitura.md).
