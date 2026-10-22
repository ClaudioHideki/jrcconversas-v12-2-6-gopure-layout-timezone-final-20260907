# Consolidação CRM GoPure / LAB — 22/10/2026

## Referências verificadas

- Base GoPure preservada: `c7ceab09d2c58ded384ee809c1feb9385edd17a8`, imagem publicada `gopure-integracao-lab2-20261022-r3`, digest `sha256:922686ada26f332d02ede970db5f035909bc37f9b4a810221e8d6d5a0db37d9f`.
- A imagem acima foi publicada e validada na sessão anterior. A imagem efetivamente em execução na produção não foi consultada nesta etapa.
- LAB consolidado: `codex/unificacao-jrc-hoya-gopure-20261021`, `9b1393a47782c4e2734dea09519787bb532df71b`.
- Campanhas: `codex/campaign-list-workflow-20261022`, `89d7a44c75e9fc7ceaeefd62491fa514e5c90f97`; CI específica aprovada no run `39802518952`.
- Projetos: `codex/projetos-telas-fluxos-20261022`, `abc1f7c57f55a7d9871101cd5b70c8b93becc7ca`; contém a atualização de Campanhas e teve CI específica aprovada no run `39812506617`. Os workflows de imagem dessa revisão ainda estavam em andamento na consulta inicial; não foram tratados como imagens concluídas.
- O branch padrão do LAB continua em `128243d925617c08896a2a9448b2bb9f6e5da115` (04/10), ancestral da consolidação. Substituir o CRM pela versão padrão eliminaria recursos recentes; não foi feito.
- O usuário autorizou consultar o histórico, consolidar as atualizações verificadas, fazer commit/push e gerar nova imagem, sem deploy.

## Diagnóstico das telas

- Clientes já existe no código consolidado: Empresas, Contatos, Segmentos, Grupos, Importações e Contatos ativos. O menu depende de `jrc_customer_master`; rotas e API mantêm permissões e isolamento por conta. Não habilitamos a flag nem alteramos o banco de produção.
- O fluxo oficial de ativação exige revisão de backfill e homologação, conforme `lib/tasks/jrc_customer_master.rake`. Não substituir isso por habilitação automática nem recriar contatos.
- Novo Negócio já usa o componente oficial `crm/views/deals/DealsIndex.vue`, com Informações, Produtos e valores e Próxima ação. A GoPure preserva o seletor paginado para contas sem Cadastro Mestre e usa os seletores oficiais de empresa/contato quando habilitado. Preços, rascunhos e controles de permissão da integração anterior permanecem.
- `LeadCreateModal.vue` é idêntico ao LAB de Projetos. O campo Canal ou origem é texto livre também no LAB; não há cadastro/API de origens de lead nessa referência. Novo Negócio possui opções fixas herdadas do LAB. Não foi inventado um cadastro, uma API ou valores de origem para simular a correção. Solicitada a localização do cadastro real ao usuário; integração desse campo permanece pendente dessa referência.

## Alterações desta consolidação

- Incorporado somente o delta `9b1393a4..abc1f7c5` em `app/` e `spec/`, depois de verificar que esses caminhos não tinham alterações GoPure em relação à base LAB. Nenhum arquivo de CRM foi substituído em massa.
- Projetos: carteira, execução, planejamento/Gantt, equipe, configuração, horas, anexos, integração operacional, serializers e verificações de acesso.
- Campanhas: entrada de público manual/CSV dentro do wizard, seleção da lista criada e elegibilidade provisória limitada a rascunhos sem remetente configurado. Consentimento e demais proteções de envio continuam obrigatórios no disparo.
- Não copiados os workflows candidatos do LAB, os ZIPs nem os arquivos de manifesto de entrega. O workflow GoPure existente recebeu os testes adicionais de Projetos/Cadastro Mestre; a publicação continua limitada ao componente app e condicionada à validação.
- Configurações isoladas de testes usam reset de mocks entre casos, como a configuração principal usada pela CI do LAB. Isso evita que a solicitação de um teste anterior contamine a verificação de ausência de escrita do seguinte.
- Não há nova migration neste delta. Todas as migrations e compatibilidades da base GoPure são preservadas.

## Limites e homologação

- Não houve consulta aos contatos reais, configuração, banco ou permissões da produção. Testes com fixtures verificam comportamento; não comprovam que o Cadastro Mestre esteja ativado na Account 2.
- Preservadas marca GoPure, integrações, credenciais, regras de WhatsApp, aprovação comercial e compatibilidade financeira legada.
- Não houve envio real, deploy ou publicação de runtime NICO nesta etapa.
- A ativação do Cadastro Mestre, validação dos contatos existentes e verificação das telas no ambiente GoPure exigem homologação separada com backup e os procedimentos oficiais.
- Commit, CI e nova imagem devem ser confirmados após sua conclusão; este documento não declara publicação antecipadamente.
