# GoPure — Cadastro e envio simplificado no CRM

Data: 2026-11-19. Estado: implementação e validações locais concluídas.

Branch local: `codex/gopure-crm-simplificado-20261119`.
Base preservada: `7899e80ff0a64a7eaf30e7d5112682a69af7fb42`.

## Resultado

1. Removido o botão global duplicado Novo lead. A criação na tela de Leads e os outros fluxos permanecem disponíveis.
2. O formulário de empresa agora oferece CEP, logradouro, número, complemento, bairro, cidade, UF e país. Usa o endereço comercial nativo, com gravação atômica junto da empresa e auditoria, preservando outros endereços.
3. Solicitar aprovação fica desativado durante o pedido e enquanto ele está pendente; aprovações concluídas permanecem desativadas e identificadas. Repetições não duplicam auditoria nem desfazem aprovação. Alterações comerciais continuam resetando os requisitos pelo fluxo nativo.
4. O envio de proposta usa um diálogo compacto com contato, novo contato, caixa, mensagem, assunto para e-mail e PDF opcional. Busca, permissões, modelos WhatsApp, idempotência e histórico são nativos. Mesmo no envio somente por link, o PDF continua no histórico da proposta. Não há envio real nos testes.

## Evidências locais

- Frontend: suíte ampla com 88 testes aprovados, seguida de verificação final com 29 testes aprovados, incluindo o novo caso de aprovação concluída. São 89 cenários distintos, sem falhas finais.
- Backend: suíte ampla com 116 exemplos e zero falhas; após organização do código, Cadastro Mestre e destinatários novamente aprovados em 40 exemplos. A aprovação final passou em 7 exemplos, incluindo o novo caso de não desfazer aprovação concluída. São 117 cenários distintos verificados.
- Prévia em navegador isolado: desktop e celular, sem erros de runtime; formulário de empresa com os oito campos de endereço, sem largura excedente. Não foi usado o navegador de produção.
- Build Vite de produção completo aprovado: 5.517 módulos, concluído em 4 min 17 s. Permanecem avisos de Browserslist, chunks grandes e uma imagem de marca resolvida em runtime, sem erro de compilação.
- CSS real de propostas públicas compilado com Vite. A primeira execução do backend encontrou sete erros de ambiente por ausência desse manifesto; a repetição com o asset real passou integralmente.
- ESLint executado nos arquivos alterados: zero erros; os avisos restantes foram revisados como ocorrências anteriores nos arquivos existentes. Não foram desativadas regras.
- RuboCop comparado por arquivo e por regra com o conteúdo da base. Comparação funcional antes dos hooks: 50 ocorrências na base e 47 na versão atual, sem aumento por arquivo/regra. A preparação da publicação também revisou as correções de formatação aplicadas pelo hook normal. Os apontamentos novos foram tratados; permanecem ocorrências de complexidade e estilo anteriores. Não se declara que o lint Ruby global esteja zerado.
- Os três containers de testes e o navegador de QA foram parados sem excluir containers, banco ou imagens. Dados exclusivamente sintéticos e rede Docker interna.

## Preservação e limites

O incremento não altera schema, dependências, Docker Compose, configuração de canais, transporte de mensagens, telefone/DDI, exclusão administrativa de pedidos, Kanban, indicadores ou respostas rápidas. A implementação usa a base publicada, sem substituir funcionalidades de outra branch.

Este relatório registra a validação local anterior à publicação. Em seguida, o usuário autorizou registrar e enviar a branch, executar a CI completa e publicar uma nova imagem somente após aprovação dos testes. SHA, execução de CI, tag e digest devem ser conferidos no comprovante final da publicação. Deploy, migrations de produção e alterações de dados reais continuam fora do escopo. O runtime Docker construído localmente serve apenas aos testes.

Referência: [ADR 0003](../adr/0003-crm-cadastro-envio-simplificado.md).
