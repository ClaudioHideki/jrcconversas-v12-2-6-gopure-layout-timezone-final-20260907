# ADR 0006 — Seleção manual e confirmação do público de campanhas

Estado: Aceita para implementação local em 25/11/2026. Publicação e implantação não executadas neste incremento.

## Contexto

Na primeira criação, quatro contatos selecionados em uma origem com 511 aptos viravam o público completo ao selecionar a caixa remetente. A assinatura usada para detectar troca de origem incluía os remetentes; seu watcher apagava o modo e as chaves da seleção. Na edição, o remetente já preenchido evitava esse caminho. A aprovação congelava corretamente o público recebido, mas não tinha uma confirmação independente da prévia anterior.

## Decisão

- Separar origem do público de remetente. A troca de caixa revalida elegibilidade sem apagar a seleção manual. Troca explícita da origem/canal mantém a redefinição prevista.
- Vincular respostas assíncronas à seleção, remetente, pesquisa e página que as originaram; ignorar respostas antigas. O botão Próximo depende de prévia atual e positiva, inclusive após a revalidação feita ao clicar.
- A prévia devolve quantidade e SHA256 das chaves/destinos ordenados. Persistir essa confirmação no JSON de público existente, sem migration e sem alterar consentimentos.
- Para campanhas com confirmação, validar criação/atualização e revisão contra o público consolidado. Não permitir retirar uma confirmação persistida por atualização acidental. Permitir uma nova seleção expressa acompanhada de nova prévia correspondente.
- Aprovação e lançamento conferem o snapshot congelado, a configuração e a confirmação. A fila deriva exclusivamente desse snapshot. O serviço de disparo rejeita destinatário ou mensagem que não pertença à campanha aprovada antes de chamar qualquer conector.
- A tela final compara o total salvo, o total da revisão e a confirmação, bloqueando divergências. Preservar o congelamento aprovado quando novos contatos forem cadastrados posteriormente.

## Compatibilidade e limites

A correção é genérica para contas e conectores. Campanhas legadas sem confirmação continuam sujeitas ao digest de revisão existente e à seleção persistida; nenhum dado é reescrito automaticamente. Uma campanha cujo cadastro anterior já perdeu a seleção não contém evidência suficiente para inferir quais quatro contatos o operador pretendia selecionar. Exige nova seleção e revisão; não há reconstrução nem disparo automático.

## Evidências

[Regressão e limites](../qa/jrc-campanhas-publico-manual-20261125.md). Todos os contatos, consentimentos e transportes utilizados nos testes são sintéticos.
