# ADR 0005 — Templates, mídia e janela operacional de campanhas

Estado: Aceita para implementação da candidata em 25/11/2026; homologação externa pendente.

## Contexto

O incidente relatado reúne parâmetros incompatíveis de templates, testes sem histórico oficial e janela interpretada como UTC. A base é `35c752d8`, preservando os incrementos anteriores. O pedido complementar exige importar o exemplo aprovado disponível e garantir separação de transporte entre Meta e Evolution.

## Decisão

- Usar a definição aprovada da caixa como contrato. Gerar campos visuais, validar componentes e bloquear configurações incompletas no frontend e no backend.
- Importar exemplos HTTPS pelo SafeFetch e validar conteúdo antes da persistência. Reutilizar o arquivo por conta, caixa e origem do template. Permitir substituição; exemplo expirado solicita upload. Nunca enviar usando um exemplo temporário como dependência permanente.
- Reutilizar `TestDelivery`, com idempotência persistente antes do I/O. Aceitação, retenção, envio, entrega, leitura, falha e resultado desconhecido têm significados diferentes. Não repetir envio ambíguo.
- Persistir eventos de status antecipados, correlacionados por caixa/WAMID, e reaplicá-los sem chamar o provider de envio.
- Manter timestamps absolutos em UTC e configurar o fuso IANA na janela de cada campanha. Novas configurações usam o fuso da conta como opção inicial. Campanhas legadas não são reinterpretadas ou reagendadas automaticamente.
- Revalidar janela e permissões na execução e na fronteira de transporte. Preservar regras próprias de Evolution/Broker, inclusive idempotência e limites.
- Encaminhar `whatsapp_cloud` somente ao provider Cloud e à API oficial da Meta. O caminho de campanhas rejeita base alternativa e não tenta Evolution/Broker quando Meta falha. Caixas `Channel::Api` seguem seus conectores explicitamente configurados.
- Reaproveitar sincronização/paginação/cache existentes, protegendo concorrência. Exigir a mesma finalidade de consentimento na prévia oficial e no envio.
- Gerar a imagem candidata em CI com `publish=false`. Guardar artefato e checksum; não publicar GHCR, fazer merge, deploy ou alterar produção sem nova autorização.

## Consequências

Migrations aditivas precisam ser avaliadas antes da atualização futura. Registros antigos sem finalidade não viram consentimentos fictícios. O operador precisa revisar fusos legados e aprovar alterações antes de uma retomada autorizada. Arquivo válido não substitui antivírus universal. Geração de imagem e aceitação HTTP não equivalem a recebimento no celular.

## Evidências

[Auditoria, testes e limitações](../qa/jrc-campanhas-20261125.md). As capturas usam componentes reais com APIs simuladas e dados sintéticos. Aceite operacional depende de ambiente Meta e destinatário de teste autorizados.
