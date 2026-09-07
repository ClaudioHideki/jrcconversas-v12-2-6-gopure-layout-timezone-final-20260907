# JRC Campanhas V12.2 — gerenciamento de destinatários

## Objetivo

Permitir que o operador ajuste individualmente quem receberá uma campanha sem alterar ou excluir registros da agenda de contatos.

## Fluxo

1. O operador escolhe o canal e a origem do público.
2. O preview aplica as regras de aptidão do canal, bloqueios, blacklist e duplicidade.
3. Em **Gerenciar destinatários**, o operador pesquisa, seleciona ou desmarca contatos.
4. A quantidade de aptos é atualizada e a campanha exige ao menos um destinatário.
5. A seleção é salva no rascunho e aplicada novamente pelo backend ao criar os destinatários do disparo.

## Comportamento da seleção

- **Selecionar todos** inclui todos os contatos aptos da origem atual.
- **Desmarcar todos** remove todos os contatos da campanha e bloqueia o avanço.
- A pesquisa aceita nome, telefone ou e-mail.
- A lista é paginada em até 50 registros por página.
- A alteração da origem ou do canal reinicia a seleção individual para evitar reaproveitar exclusões de outro público.
- Contatos retirados permanecem normalmente na agenda e podem participar de outras campanhas.
- O mesmo comportamento é aplicado a WhatsApp, E-mail e listas sanitizadas.

## Persistência e compatibilidade

As regras são armazenadas em `audience_config`, campo JSON já existente na campanha. Não há migration, tabela nova ou alteração no banco de contatos. Campanhas anteriores continuam utilizando todos os contatos aptos enquanto não houver seleção individual configurada.
