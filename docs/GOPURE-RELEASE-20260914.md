# GoPure — CRM e disponibilidade — 14/09/2026

Esta atualização incorpora as mudanças do ZIP validado ao repositório GoPure, mantendo a configuração de fuso horário `APP_TIME_ZONE=America/Sao_Paulo` já existente.

- Visual GoPure e rolagem visível nos relatórios e seus submenus.
- Nove opções de disponibilidade com cores no menu, cabeçalho e avatar. A seleção permanece após recarregar a página; somente Disponível recebe distribuição automática. O estado antigo Ocupado continua compatível.
- Quando o Super Admin ativa o CRM na conta, administradores e agentes têm acesso ao módulo, sem liberação individual.
- Somente administradores gerenciam produtos e visualizam custos, margens e indicadores gerais. Agentes consultam produtos sem custos e margens e visualizam seus próprios indicadores.
- O indicador de e-mails não lidos considera mensagens recebidas ainda não vistas nas caixas permitidas para o usuário.

## Imagem Docker

O workflow `Build GoPure - CRM e disponibilidade` publica a imagem para Linux no GHCR após uma atualização da branch `main`:

```text
ghcr.io/claudiohideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907:4.16.2-jrc-v12.2.6-gopure-20260914
```

Também é publicada uma tag `sha-<commit>` para identificar exatamente o código compilado. A nova tag não substitui a tag antiga usada pela instalação existente. A aplicação em produção depende de atualizar a imagem na configuração do serviço.

As alterações de disponibilidade reutilizam as colunas existentes. A ativação do CRM continua sendo uma configuração da conta no banco de dados.
