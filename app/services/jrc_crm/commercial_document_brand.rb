module JrcCrm
  # Presentation only: the same opt-in/opt-out rule used by useCrmTheme.
  # Never changes prices, recurrence, taxes, permissions or tenant scope.
  module CommercialDocumentBrand
    private

    def document_gopure?(account)
      configured = (account.custom_attributes || {})['crm_theme']
      return configured == 'gopure' if configured.present?

      account.name.to_s.downcase.gsub(/\s/, '') == 'gopure'
    end

    def document_logo_path(account)
      name = document_gopure?(account) ? 'gopure-brand-header.png' : 'logo-jrc.png'
      Rails.root.join('public', 'brand-assets', name)
    end
  end
end
