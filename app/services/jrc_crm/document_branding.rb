module JrcCrm::DocumentBranding
  extend JrcCrm::CommercialDocumentBrand
  NAME = 'GoPure JRC Conversas'.freeze
  LOGO_RELATIVE_PATH = 'public/brand-assets/gopure-brand-header.png'.freeze
  MUTEX = Mutex.new
  def self.name(account = nil)
    account && !document_gopure?(account) ? 'JRC Conversas' : NAME
  end

  def self.primary_color(account = nil)
    account && !document_gopure?(account) ? [0.05, 0.27, 0.53] : [0.0, 0.42, 0.29]
  end

  def self.logo_path(account = nil)
    return document_logo_path(account).to_s if account

    root = defined?(Rails) && Rails.respond_to?(:root) ? Rails.root.to_s : File.expand_path('../../..', __dir__)
    File.join(root, LOGO_RELATIVE_PATH)
  end

  def self.logo(account = nil)
    path = logo_path(account)
    stat = File.stat(path)
    key = [path, stat.size, stat.mtime.to_f]
    MUTEX.synchronize do
      if @logo_key != key
        @logo_data = JrcCrm::CommercialPdf::Logo.load(path)
        @logo_key = key
      end
      @logo_data
    end
  rescue Errno::ENOENT => e
    raise JrcCrm::CommercialPdf::Logo::InvalidImage, "Logo oficial GoPure ausente: #{e.message}"
  end
end
