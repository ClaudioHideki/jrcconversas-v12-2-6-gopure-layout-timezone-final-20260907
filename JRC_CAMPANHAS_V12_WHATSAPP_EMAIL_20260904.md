# JRC Campanhas V12 — WhatsApp e E-mail

## O que mudou

- O assistente de campanha agora separa a **origem do público** do **canal de envio**.
- Todos os contatos, etiquetas, caixa de origem, etapa do CRM/Kanban e lista sanitizada podem ser usados com WhatsApp ou e-mail.
- WhatsApp exige telefone válido; e-mail exige endereço válido.
- A configuração de envio lista somente caixas compatíveis com o canal escolhido.
- Campanhas de e-mail possuem assunto, corpo, variáveis, sequência, anexo opcional, teste e preview próprios.
- O envio de e-mail usa a caixa `Channel::Email` e a configuração SMTP/OAuth já existente.
- Respostas por e-mail são vinculadas ao destinatário da campanha e acionam as mesmas ações de resposta (etiqueta/CRM).
- Listas sanitizadas aceitam `nome,telefone,email`, cabeçalho opcional ou uma única coluna de telefone/e-mail.
- Relatórios, CSV, filtros e resumo identificam o canal e o destino usado.

## Atualização local

Depois de substituir os arquivos da aplicação, execute:

```bash
bundle exec rails db:migrate
pnpm install
pnpm dev
```

Reinicie também os workers do Sidekiq, pois o disparo continua sendo processado em jobs.

## Teste rápido de e-mail

1. Confirme que existe uma caixa de e-mail com SMTP ou OAuth habilitado.
2. Crie um novo disparo e escolha **E-mail** no primeiro passo.
3. Escolha qualquer origem de público e confira a quantidade de contatos com e-mail válido.
4. Selecione a caixa de e-mail, configure assunto e conteúdo e envie um teste.
5. Revise as pendências e inicie a campanha.

O aceite do servidor SMTP representa o status **Enviado**. Entrega e leitura dependem de eventos oferecidos pelo provedor; respostas recebidas são rastreadas normalmente pela conversa.
