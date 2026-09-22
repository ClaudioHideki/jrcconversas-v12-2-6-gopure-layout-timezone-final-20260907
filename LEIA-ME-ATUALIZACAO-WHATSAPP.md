# GoPure / JRC Conversas - Janela WhatsApp e templates

Atualização de 21/09/2026, feita sobre o ZIP GoPure enviado nesta conversa.

## O que muda para o atendente

A conversa mostra se a janela do WhatsApp Oficial está aberta, quanto tempo resta e quando chegou a última mensagem do cliente. Quando a janela fecha, aparece **Escolher modelo**. O agente escolhe um modelo aprovado, revisa o texto, preenche as variáveis e envia.

**Enviar o modelo não libera a mensagem comum: o cliente precisa responder.** As notas internas continuam disponíveis.

O administrador encontra a nova aba em:

**Configurações > Caixas de entrada > selecionar a caixa WhatsApp > Templates WhatsApp.**

Essa aba permite sincronizar modelos, definir equipes autorizadas, favoritos e preenchimento automático, além de consultar o histórico de envios.

## Para publicar no servidor

Este ZIP contém o **código-fonte completo atualizado**. Não é uma imagem Docker já compilada. Copiar o ZIP para o servidor ou reiniciar uma imagem antiga não ativa a atualização.

1. Guarde o ZIP anterior e faça backup do banco e da configuração. Extraia o pacote em uma pasta nova, sem sobrescrever o ambiente em uso antes da validação.
2. Publique o código pelo processo que seu servidor já utiliza. O Dockerfile e o workflow `.github/workflows/build-ghcr.yml` foram preservados. Quando usar esse workflow, confirme que terminou com sucesso e selecione a imagem **app-sha-... do novo commit**, não uma imagem antiga.
3. Atualize os serviços da aplicação e do processamento de mensagens (Rails e Sidekiq) para a mesma imagem nova. Preserve banco, Redis, volumes, domínio e variáveis de ambiente. O runtime NICO não foi modificado nesta atualização.
4. Entre como administrador, abra a aba **Templates WhatsApp** na caixa correta e clique em **Sincronizar agora**. Valide com um contato de teste autorizado antes de usar na operação.

**Esta alteração não adiciona migrations nem exige recriar banco, Redis ou contas.** Mantenha suas credenciais atuais. Nada foi aplicado ao servidor durante a preparação deste ZIP.

## Conferência após publicar

Abra uma conversa cuja última mensagem do cliente tenha mais de 24 horas. A mensagem comum deve estar bloqueada, mas a nota interna deve funcionar. Envie um modelo aprovado e confira o histórico. Antes de o cliente responder, o texto comum deve continuar bloqueado. Depois de uma resposta real do cliente, a interface deve liberar o atendimento sem recarregar a página.

Confira também o acesso de um agente sem permissão administrativa e de outra caixa/empresa: os modelos e os dados não devem se misturar.

Para preencher `{{1}}`, `{{2}}` etc. automaticamente, vincule cada variável ao campo correto na aba administrativa. O sistema não adivinha o significado dos números. Nomes claros, como `{{nome}}`, podem receber sugestões; o agente revisa antes de enviar.

## Validações realizadas

Foram aprovados **41 testes isolados de serviços Ruby (123 verificações)** e **17 testes JavaScript**. Também foram verificadas a sintaxe dos arquivos alterados, a compilação dos templates de nove componentes Vue e cinco cenários de interface no Chromium com dados e respostas simulados.

**Não foram executados o build completo da aplicação, o Rails com PostgreSQL/Redis nem um envio real à Meta nesta preparação.** Os testes isolados não substituem a homologação da imagem e do número real antes de produção.

Detalhes, limites e comandos dos testes: `docs/whatsapp-24h/IMPLEMENTACAO-E-TESTES.md`.

Lista de arquivos e hashes: `docs/whatsapp-24h/ARQUIVOS-ALTERADOS.json`.
