# GoPure — atualização visual do V12.2.4

Base: JRC-V12-2-4-CRM-AGENTES-EMAIL-PRODUTOS-20260908.zip.
Atualização: 14/09/2026.

## Alterações deste pacote

- Identidade GoPure no menu: logotipo original, fundo verde, botão Criar e rodapé.
- Cores e gradientes GoPure no Cockpit, conforme a referência fornecida.
- Seletor de contas preservado.
- Área dos relatórios com altura limitada à tela e barra de rolagem visível.
- Submenus longos deixam de ocultar a barra de rolagem.

A base funcional é o V12.2.4. Após a primeira validação, foram acrescentados os estados de disponibilidade solicitados, descritos abaixo. As regras de produtos e indicadores do CRM foram preservadas.

## Verificações realizadas no ambiente local

26 verificações de integração passaram usando os controladores reais da aplicação:

- CRM acessível para administrador e agente com a funcionalidade habilitada na conta, mesmo com crm_enabled individual falso.
- Administrador pode criar, editar, ativar/desativar e excluir produtos.
- Agente consulta produtos sem receber custo ou margem nas respostas da API.
- Tentativas do agente de cadastrar, editar, ativar/desativar ou excluir produtos são recusadas, sem alterar o cadastro. O importador do catálogo usa a mesma API de criação protegida.
- Administrador vê indicadores de todos os responsáveis.
- Agente vê indicadores apenas dos próprios negócios, inclusive quando tenta informar outro owner_id na requisição.
- Agente não acessa negócio de outro responsável.
- E-mail recebido incrementa o contador do Cockpit; a leitura zera o contador; uma nova mensagem volta a incrementá-lo.
- Caixa de e-mail sem acesso não entra na contagem do agente.

Verificação no navegador:
- Identidade GoPure carregada no Cockpit.
- CRM e catálogo acessíveis para ambos os perfis.
- Novo produto, importação, margem e filtro de responsáveis disponíveis apenas para administrador.
- Agente recebe Meu Desempenho no lugar dos relatórios gerais.
- Relatório geral rolou até o final, com barra visível.

Compilação do frontend com Vite concluída com sucesso em modo development.
ESLint comparado com os mesmos arquivos originais: nenhuma ocorrência nova; existem avisos e erros prévios no pacote base.
Os registros temporários usados nas verificações de integração foram revertidos.

## Ativação

O Super Admin ativa o CRM para a conta. Após essa ativação, administradores e agentes da conta têm acesso ao módulo, sem liberação individual. O administrador gerencia produtos e consulta os indicadores gerais; o agente consulta produtos sem custos ou margens e vê os indicadores dos próprios negócios. A ativação é uma configuração no banco de dados e foi habilitada na conta 1 do ambiente local para validação.

O teste de e-mail validou a aplicação com mensagens locais. Não valida conexão com provedores IMAP/SMTP externos.

Este pacote contém código-fonte. A instalação deve recompilar os assets conforme o procedimento já usado para esta aplicação.

## Disponibilidade ampliada e colorida

As opções seguem a referência solicitada, nesta ordem:

| Estado | Cor |
| --- | --- |
| Disponível | Verde |
| Indisponível | Cinza |
| Reunião | Azul |
| Feedback | Violeta |
| Fim do turno | Cinza neutro |
| Treinamento | Índigo |
| Pausa banheiro | Ciano |
| Pausa almoço | Amarelo |
| Chamada Manual | Rosa |

Menu, cabeçalho e indicador do avatar usam a mesma definição de cores. O cadastro de agentes também aceita esses estados.
A lista de disponibilidade tem largura e rolagem para comportar as opções.
O valor legado Ocupado continua legível para contas que já o utilizavam, mas o menu oferece os motivos específicos da referência.

Os estados foram adicionados aos enums User e AccountUser mantendo os códigos anteriores (0, 1 e 2). As colunas existentes são inteiras; não é necessária migração de estrutura.

Somente Disponível participa da distribuição automática de novas conversas. As pausas entram no total de ocupados do Cockpit; Fim do turno entra no total de offline, sem perder pessoas na soma da equipe.

93 verificações adicionais de integração passaram, cobrindo administrador e agente, gravação e recarga de cada estado, compatibilidade com Ocupado, isolamento por conta, elegibilidade de distribuição e totais da equipe. Os estados anteriores foram restaurados ao terminar.
No navegador, as nove cores foram verificadas pelo estilo renderizado. Treinamento foi selecionado, permaneceu após recarregar e exibiu a mesma cor no cabeçalho. O usuário foi devolvido a Disponível.

O frontend foi compilado novamente com Vite em modo development. A verificação de sintaxe Ruby passou. Nos componentes alterados, o único aviso ESLint remanescente é a propriedade crmEnabled não utilizada, que já existia no EditAgent.vue original.
