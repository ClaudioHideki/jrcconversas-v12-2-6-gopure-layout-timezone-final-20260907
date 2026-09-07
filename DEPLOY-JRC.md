# JRC Conversas V12.2 — publicação no GHCR

Imagem principal:

`ghcr.io/claudiohideki/jrcconversas-v12-campanhas-whatsapp-email-20260904:4.16.2-jrc-v12.2-20260904`

O workflow `.github/workflows/build-ghcr.yml` é executado automaticamente ao enviar a branch `main`. O workflow `.github/workflows/publish-ghcr.yml` também pode ser executado manualmente em **Actions → Publicar imagem JRC Conversas no GHCR → Run workflow**.

O build automático publica:

- `4.16.2-jrc-v12.2-20260904`
- uma tag imutável baseada no commit (`sha-...`)

O build manual também publica a tag auxiliar `v12.2`.

O build está configurado para `linux/amd64`, compatível com o servidor atual do Dokploy.

O repositório e as imagens anteriores permanecem independentes e não devem ser apagados ou reutilizados por esta versão.
