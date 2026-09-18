# GoPure + NICO — implantação de 18/09/2026

Base: GOPURE-CRM-LOCAL-ATUALIZADO-20260918.zip. Recursos NICO provenientes de
jrc-conversas-nico-v12-2-7-comercial-integrado-main (7).zip.
O layout GoPure, CRM atualizado, pedidos, contratos, comissões, paginação,
busca, vínculo Contato → Lead e campanhas de e-mail foram preservados.

## Duas imagens

Repositório GHCR: `ghcr.io/claudiohideki/jrcconversas-v12-2-6-gopure-layout-timezone-final-20260907`.

| Serviço | Tag |
|---|---|
| GoPure Rails + frontend; mesma imagem para Sidekiq | `4.16.2-gopure-nico-20260918-r1` |
| NICO Runtime Node 24 | `nico-runtime-gopure-20260918-r1` |

O workflow publica as duas tags e tags por commit. Não publica `latest`, não
substitui a tag anterior de 17/09 e não remove imagens. Builds futuros desta
versão atualizam apenas suas próprias tags; fixe o digest para uma implantação imutável.

## Dokploy

1. Guarde o compose, variáveis, digest da imagem atual e backup consistente do
   banco GoPure antes da janela de atualização. Preserve os volumes atuais.
2. Crie o serviço **gopure-nico-runtime** com `gopure-nico-runtime.compose.yml`.
   Use a mesma rede interna da aplicação, sem domínio público. Mantenha o volume
   `/runtime-data` persistente. O LAB continua com seu runtime independente.
3. Configure `GOPURE_ACCOUNT_ID` com o ID confirmado da conta GoPure. A captura
   mostra `/accounts/2`; confirme no Super Admin. Não copie `1` do LAB. O runtime
   em modo provider aceita **uma conta**; não use `1,2` para compartilhar LAB.
4. Crie um **novo** `NICO_SERVICE_TOKEN` (mínimo 32 caracteres), igual no runtime,
   Rails e Sidekiq da GoPure. Configure uma nova `NICO_PROVIDER_API_KEY` somente
   no runtime. Substitua as credenciais anteriormente compartilhadas na conversa.
   Não coloque chaves no Git, no ZIP, no navegador nem em Docker build args.
5. Mescle `gopure-app.compose.override.yml` no compose atual. Preserve os nomes
   reais dos serviços, DB, Redis, `SECRET_KEY_BASE`, storage, SMTP, domínio,
   labels e demais variáveis. Rails e Sidekiq devem alcançar
   `http://gopure-nico-runtime:3108` na rede do Dokploy.
6. Pare os consumidores antigos durante a migração e execute **uma vez**, usando
   a nova imagem da aplicação e as variáveis/volumes atuais:
   `bundle exec rails db:migrate`. Não use `db:reset`, `db:schema:load` ou seeds
   em produção. Depois atualize Rails e Sidekiq para a mesma nova tag/digest.
7. No Super Admin → Accounts → Edit da GoPure, mantenha o CRM habilitado e
   habilite **NICO**, ajustando execuções, tokens e simultaneidade. A configuração
   pertence à conta; agentes e administradores conservam suas permissões.
8. Verifique `/health` pela rede interna, depois teste uma solicitação de leitura
   do NICO no painel, criação de lead com confirmação, histórico e transcrição
   com áudio de teste. `/health` pronto não comprova a chave/provedor: por projeto,
   o campo `provider_verified` continua falso até uma chamada real ser validada.

As variáveis de Nixpacks não são necessárias ao selecionar imagem Docker pronta.
PostgreSQL, Redis e GoPure static existentes continuam sendo utilizados. As
capturas não permitem concluir que o serviço app foi removido; localize o app
atual antes de criar outro e evite dois workers consumindo a mesma fila.

## Recursos e permissões

- NICO rápido pelo mascote e painel completo, sessão compartilhada, contexto da
  conversa, voz, revisão de transcrição e confirmação explícita de ações.
- Especialistas, análises, histórico auditável, conhecimento, avisos, propostas,
  atividades, delegação comercial limitada no tempo e interrupção por atendimento humano.
- Novo lead pelo NICO usa a deduplicação e transação do CRM GoPure: localiza ou
  cria Contact, vincula Lead e reutiliza o lead existente sem duplicar cadastro.
- Agentes acessam seu CRM autorizado. Produtos, aprovações, configuração e
  campanhas seguem as restrições administrativas do NICO de referência.
- Campanhas exigem revisão/aprovação humana válida; WhatsApp verifica opt-in,
  bloqueios e janela aplicável. E-mails mantêm assunto, anexos e canal próprios.
  Revise campanhas agendadas preexistentes antes de retomar: sem aprovação
  válida elas não disparam automaticamente.
- ERP exige configuração e credenciais próprias; o conector está no código,
  mas não está automaticamente conectado a um ERP GoPure. Chamadas exigem
  canais/ramal registrados e navegador disponível, como no LAB.

## Retorno

Mantenha o digest/tag anterior e o backup do banco. Desabilitar NICO pela conta
interrompe novas autorizações. Voltar a imagem exige avaliar compatibilidade das
migrações de CRM/NICO e dados novos; não reverta migrações automaticamente.
Este pacote prepara a implantação; publicar no Git/GHCR não altera o servidor.
