# JRC Conversas V12-2-2 — Ajustes UX / E-mail / Scroll

Data: 2026-09-06
Base preservada: `jrcconversas-v12-2-1-campanhas-whatsapp-email-fix-20260905-main(1).zip`

## Ajustes realizados

1. **Contatos**
   - Lista de contatos passa a ter rolagem vertical própria quando o conteúdo ultrapassa a altura disponível.
   - Cabeçalho da tabela fica fixo durante a rolagem.
   - Painel lateral de detalhes mantém rolagem independente.
   - Botão **Novo contato** recebeu fundo azul explícito e contraste garantido para evitar aparência transparente.

2. **Rolagem nas telas JRC**
   - Adicionada utilidade `jrc-visible-scrollbar` com barra de rolagem visível.
   - Aplicada em Contatos, Cockpit, E-mails, Ligações, CRM e Campanhas, preservando o comportamento de rolagem de cada módulo.
   - Conversas continuam usando painéis independentes para não quebrar lista, histórico e painel lateral.

3. **WhatsApp Calling — tradução pt-BR**
   - Adicionado bloco `SIDEBAR` que faltava em `pt_BR/whatsappCalling.json`.
   - `Keypad` -> **Teclado**.
   - `Hide keypad` -> **Ocultar teclado**.
   - Também foram incluídos os demais textos do painel lateral em português brasileiro para evitar fallback para inglês.

4. **E-mails / Caixa de entrada**
   - A antiga funcionalidade **Caixa de Entrada** foi incorporada ao módulo **E-mails** como submenu/aba **Caixa de entrada**.
   - O acesso abre `inbox_view` já filtrado por `channel=email`.
   - A tela principal de E-mails ganhou navegação explícita entre **Visão geral** e **Caixa de entrada**.
   - O item legado `Inbox` deixa de aparecer isolado em **Outros recursos**, sem remover sua rota ou funcionalidade.

5. **Configurações**
   - Nenhuma funcionalidade, rota ou submenu existente em Configurações foi removido neste pacote.
   - A estrutura de Configurações foi preservada para manter Conta, Agentes, Times, Caixas de Entrada, Etiquetas, Atributos Personalizados, Automação, Robôs, Macros, Respostas Prontas, Integrações, Dados, Fluxo de Conversa e demais recursos existentes.

## Regra de compatibilidade

As alterações são aditivas/de UX e não removem funcionalidades existentes. O ZIP base deve continuar preservado para rollback.
