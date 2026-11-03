# URA nativa HML — 3 de novembro de 2026

O Broker executa a automação; o Conversas hospeda o editor integrado e o atendimento humano. A execução da caixa delegada tem autoridade única. A configuração não exige Typebot, n8n/Bridge ou Budibase para executar o Flow publicado. Os demais usos administrativos do Budibase não foram migrados por inferência.

## Fontes e integração

- Destino: `216aa1e0a66372a20a68c0d092f0dadfb0541620`, branch GoPure `codex/gopure-proposta-aceite-20261029`.
- LAB2 atual: `a30fb50e6e53f1bc9eebe66ce50d13e46820b1c8`; código executável anterior `edd6f1a2570676a64d0e9086652c8e1da476c7ac`.
- Broker inicial: `c0cd026e3d0e87ece7c7a5aa036e70c1b0f7ad37`.
- Branch HML nos dois destinos: `codex/ura-nativa-hml-20261103`.

Os históricos GoPure e LAB2 não têm ancestral comum: suas raízes são `a46cceaa338109b06731eafcb8b57708e6bc7cf9` e `e89089a0ca66d9ec5b5cde8e4130918afe314bd5`. A integração GoPure anterior documenta a incorporação do LAB2 `abc1f7c57f55a7d9871101cd5b70c8b93becc7ca` em `docs/integrations/gopure-crm-padrao-lab-20261022.md`. Esse snapshot foi usado explicitamente como base de comparação de três vias, sem inventar ancestralidade e sem substituir a árvore inteira. O commit de integração registra os dois pais.

O delta LAB2 tem 1.152 caminhos e 26 migrations novas, todas posteriores ao schema GoPure anterior. As resoluções preservam acréscimo comercial, documentos/pedidos legados e identidade por conta, incorporando a recorrência financeira V3, os módulos atuais e a nova transferência humana. O teste GoPure de reversibilidade de Projetos mantém schema descartável para não derrubar módulos posteriores. A navegação usa o helper existente com Backoffice incluído. Os workflows de produção anteriores não são usados para publicar HML.

## Migração do exemplo

O export fornecido é OIA Global/Teste, e não uma certificação do fluxo produtivo. Possui 38 blocos, 11 menus, 18 variáveis e oito chamadas ao Bridge. A conversão corrigida mantém rich text como texto, referências de início, nomes de variáveis, cada opção e os retornos a blocos específicos. Referências atuais têm precedência sobre arestas históricas não referenciadas. Referência quebrada não é transformada silenciosamente em uma sequência linear.

O resultado local tem 83 nós, 106 conexões, 44 saídas de menu e nenhuma mensagem vazia. As oito ações externas permanecem sem suporte e bloqueiam publicação até substituição por destinos nativos autorizados. O webhook de origem só envia departamento: a atribuição ao atendente escolhido não pode ser certificada sem o catálogo real e a regra correspondente do Bridge. Variáveis de horário declaradas não são prova de uma regra de horário executada. CRF não foi fornecido.

## Sequência de entrega

1. Integrar as bases preservando as adaptações GoPure.
2. Corrigir a conversão com testes RED/GREEN sintéticos e conferir o original apenas localmente.
3. Commitar Broker; gerar editor pelo script oficial e instalar seu manifesto no Conversas.
4. Executar os gates GoPure e os dois jobs nativos atuais do LAB2 antes do build.
5. Publicar tags HML derivadas do SHA e registrar digests, labels, plataforma e SHA interno.
6. Implantar posteriormente recursos HML próprios e vincular o canal autorizado pelos contratos de integração.

Build, publicação, implantação, entrega no dispositivo e paridade do cliente são evidências distintas. Nenhum teste sintético é apresentado como WhatsApp real.
