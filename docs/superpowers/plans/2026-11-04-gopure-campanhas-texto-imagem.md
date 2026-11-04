# Campanhas GoPure — texto e imagem

## Escopo e base confirmados

- Repositório GoPure, sem importar os demais módulos do LAB2.
- Base `216aa1e0a66372a20a68c0d092f0dadfb0541620`.
- Compose consultado em 04/11: imagem `gopure-proposta-aceite-20261029-r1` com digest `79f22bbd41bace8b8d9d6669cd11b4bac72eaaf6dd4a43d46e4ba5bf69c30acf`.
- Os SHA256 (normalizados LF) de EvolutionClient, DispatchStepService e CampaignWizard coincidem com os arquivos lidos no container Rails.
- Transporte existente: Evolution direta, com opção Broker preservada. UI existente já oferece lista manual/CSV, caixa remetente, upload e legenda.

## Incrementos

1. Reproduzir por regressão o nome de imagem incompatível com a conversão JPEG da Evolution e a dependência de URL pública para arquivos já importados.
2. Corrigir somente o caminho de campanhas: nome compatível no envio Evolution e leitura do arquivo da biblioteca da própria Account. Preservar legenda, remetente escolhido, limite de mídia, SSRF, idempotência e UNKNOWN sem reenvio cego.
3. Preservar o anexo importado no histórico local, inclusive na recuperação do registro após falha. Não duplicar mensagens enviadas.
4. Executar Rails/PostgreSQL/Redis isolados e testes de campanhas existentes. Revisar diff e preparar candidata rastreável.

## Limites

Nenhuma migração, troca de engine, importação de dados ou alteração de credenciais. Nenhum envio real de teste foi solicitado neste incremento. Publicação, implantação e entrega real são evidências distintas. A imagem candidata deve incluir apenas esta alteração sobre a base produtiva GoPure; branches HML/URA mais novas não serão incorporadas automaticamente.
