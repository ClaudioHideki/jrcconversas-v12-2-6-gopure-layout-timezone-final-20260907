# Instalação HML e número já conectado ao Broker

Esta entrega prepara imagem e configuração; não troca banco, sessão ou webhook de produção. O número informado pelo usuário já está no Broker. Preservar o canal e a identidade existentes: vincular a integração do Conversas ao canal autorizado, sem criar outra sessão WhatsApp ou parear o mesmo número em outra engine.

## Instância Conversas isolada

Use `deploy/ura-hml/compose.yml`. Copie `.env.example` para `.env` no servidor e preencha os valores em ambiente privado. Use o digest final publicado, origem HTTPS real, segredo Rails e chave Broker próprios. `JRC_BROKER_ALLOWED_ORIGINS` é uma lista de origens exatas separadas por vírgula; não aceita paths, portas explícitas ou IDs arbitrários.

O Compose cria PostgreSQL, Redis e storage próprios. O nome do projeto deve ser exclusivo. A porta HTTP fica em loopback para um proxy HTTPS no host. Nenhum domínio, conta, canal ou time de cliente é predefinido.

```sh
docker compose --env-file .env config --quiet
docker compose up -d postgres redis
docker compose --profile maintenance run --rm migrate
docker compose up -d rails sidekiq
```

Confirme saúde do banco/cache, `/api`, registro do Sidekiq, HTTPS e storage. Rails e Sidekiq usam a mesma imagem. Não execute `down --volumes`. O Compose não atualiza o Broker existente nem presume sua versão. Na atualização autorizada do Broker, API e workers devem usar a mesma revisão compatível; aplique primeiro suas migrations pelos procedimentos existentes, com as flags e os workers requeridos.

## Configuração pelo produto

1. Criar conta, administrador e agente HML; habilitar apenas as features necessárias nessa conta pelos mecanismos existentes.
2. No Broker, autorizar explicitamente a origem HTTPS da HML e o vínculo organização/conta/caixa. Criar a credencial de controle pelo fluxo existente; não usar token de usuário para simular o executor.
3. No Conversas, abrir Conexões do Broker, configurar a integração e vincular a caixa ao canal de teste já conectado. Adoção de caixa API e troca de callback precisam se limitar à caixa HML designada.
4. Registrar/delegar o editor Broker Flow e realizar o cutover pelo protocolo existente. Não editar `LEGACY/FENCED` por SQL. Remover a concorrência do AgentBot externo apenas nessa caixa autorizada.
5. Criar fluxo nativo ou importar o JSON como rascunho. Na OIA/Teste, substituir as oito ações externas por transferências nativas com destinos selecionados do catálogo da conta. Revisar o marcador de importação antes de publicar. Não remover controles para simular compatibilidade.
6. Usar Playground, publicar uma versão e vincular à caixa. Testar com contato autorizado: entrada → idioma → departamento → escolha → transferência → resposta humana.

A transferência nativa exige políticas compatíveis; por exemplo, não deixar uma atribuição automática concorrente disputando o destino escolhido. Respeitar as pré-condições apresentadas pelo catálogo e corrigir a configuração de HML.

## Aceite e limites

Verificar os dois idiomas, as 26 escolhas finais de atendimento, oito retornos de menu e entrada inválida. Confirmar um único executor, persistência após reinício, eventos duplicados, isolamento entre contas e prioridade humana. Confirmar recebimento no dispositivo e agente/time efetivamente atribuído. Depois do handoff, a retomada é explícita.

Configure horários de negócio no Flow com `America/Sao_Paulo` e verifique a apresentação com outro fuso de navegador. `DEFAULT_LOCALE=pt_BR` define o idioma padrão; não altera timestamps históricos nem prova o fuso de `Time.current` do Rails.

Imagens e configuração prontas não certificam CRF, OIA produtiva, entrega WhatsApp nem substituição integral das funções de provisionamento do Budibase. A homologação integrada depende do servidor/origem HML, catálogo e contato autorizados, que não foram inferidos das capturas antigas.
