require 'mini_magick'

module JrcCrm
  class ContractPdfService
    PAGE_WIDTH = ProposalPdfService::PAGE_WIDTH
    PAGE_HEIGHT = ProposalPdfService::PAGE_HEIGHT
    GREEN = ProposalPdfService::GREEN
    GREEN_2 = ProposalPdfService::GREEN_2
    LIGHT_GREEN = ProposalPdfService::LIGHT_GREEN
    TEXT = ProposalPdfService::TEXT
    MUTED = ProposalPdfService::MUTED
    WHITE = ProposalPdfService::WHITE
    BORDER = ProposalPdfService::BORDER

    def initialize(contract)
      @contract = contract
      @order = contract.sales_order
      @deal = contract.deal
      @contact = contract.contact
      @items = contract.contract_items.presence || @order.order_items
    end

    def call
      ProposalPdfService::PdfDocument.new([cover_page, terms_page], logo: logo_data).render
    end

    private

    def cover_page
      page = base_page('CONTRATO COMERCIAL')
      page.text(48, 708, contract_title, size: 25, bold: true, color: GREEN)
      page.multiline(48, 666, 'Instrumento comercial de contratação de produtos e serviços GoPure.', size: 11, color: MUTED, width_chars: 74, leading: 16)
      page.fill_rect(48, 490, 499, 132, LIGHT_GREEN)
      info_row(page, 588, 'CONTRATANTE', customer_name)
      info_row(page, 550, 'CONTRATO', @contract.contract_number)
      info_row(page, 512, 'PEDIDO / VENDA', @order.order_number)

      page.text(48, 455, 'Resumo da contratação', size: 12, bold: true, color: GREEN_2)
      y = 420
      y = commercial_row(page, y, 'Valor único', money(@contract.one_time_cents))
      y = commercial_row(page, y, 'Mensalidade', "#{money(@contract.monthly_cents)}/mês")
      y = commercial_row(page, y, 'Vigência', validity)
      y = commercial_row(page, y, 'Renovação', renewal_label)
      commercial_row(page, y, 'Índice de reajuste', @contract.adjustment_index.presence || 'IPCA')

      page.text(48, 164, 'Responsável comercial', size: 8, bold: true, color: MUTED)
      page.text(48, 143, @contract.owner&.name.presence || 'Equipe GoPure', size: 11, bold: true, color: TEXT)
      footer(page)
      page
    end

    def terms_page
      page = base_page('ESCOPO E CONDIÇÕES')
      page.text(48, 720, 'Produtos e serviços contratados', size: 12, bold: true, color: GREEN_2)
      y = draw_items(page, 688)
      y -= 18
      page.text(48, y, 'Condições gerais', size: 12, bold: true, color: GREEN_2)
      y -= 24
      clauses.each_with_index do |clause, index|
        y = page.multiline(48, y, "#{index + 1}. #{clause}", size: 9, color: TEXT, width_chars: 88, leading: 14)
        y -= 11
      end
      page.text(48, 110, 'Assinaturas', size: 11, bold: true, color: GREEN_2)
      page.line(48, 80, 260, 80, color: MUTED, width: 0.6)
      page.line(330, 80, 542, 80, color: MUTED, width: 0.6)
      page.text(48, 64, customer_name, size: 8, bold: true, color: TEXT)
      page.text(330, 64, 'GoPure - Grupo JRC', size: 8, bold: true, color: TEXT)
      footer(page)
      page
    end

    def base_page(title)
      page = ProposalPdfService::Page.new
      page.fill_rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, WHITE)
      page.fill_rect(0, 0, 10, PAGE_HEIGHT, GREEN)
      page.logo(420, 772, 120, 36)
      page.text(48, 796, 'GOPURE | DOCUMENTO COMERCIAL', size: 8, bold: true, color: GREEN)
      page.text(48, 770, title, size: 19, bold: true, color: GREEN)
      page.line(48, 755, 547, 755, color: GREEN_2, width: 1)
      page
    end

    def info_row(page, y, label, value)
      page.text(64, y, label, size: 7.5, bold: true, color: MUTED)
      page.text(212, y, value, size: 10.5, bold: true, color: TEXT)
    end

    def commercial_row(page, y, label, value)
      page.text(58, y, label, size: 10, color: TEXT)
      page.text(374, y, value, size: 10, bold: true, color: GREEN)
      page.line(48, y - 10, 547, y - 10, color: BORDER, width: 0.5)
      y - 29
    end

    def draw_items(page, y)
      rows = @items.to_a.first(7)
      page.fill_rect(48, y - 26, 499, 26, GREEN_2)
      page.text(56, y - 17, 'ITEM', size: 7, bold: true, color: WHITE)
      page.text(350, y - 17, 'QTD.', size: 7, bold: true, color: WHITE)
      page.text(418, y - 17, 'VALOR', size: 7, bold: true, color: WHITE)
      y -= 26
      rows.each_with_index do |item, index|
        page.fill_rect(48, y - 38, 499, 38, index.even? ? WHITE : [0.976, 0.982, 0.989])
        name = item.respond_to?(:name_snapshot) ? item.name_snapshot : item.name
        quantity = item.quantity.to_s
        value = if item.respond_to?(:initial_total_cents)
                  item.initial_total_cents
                else
                  item.one_time_cents.to_i + item.recurring_cents.to_i
                end
        page.text(56, y - 16, name.to_s.slice(0, 48), size: 8.5, bold: true, color: TEXT)
        page.text(350, y - 16, quantity, size: 8.5, color: TEXT)
        page.text(418, y - 16, money(value), size: 8.5, color: TEXT)
        page.line(48, y - 38, 547, y - 38, color: BORDER, width: 0.5)
        y -= 38
      end
      y
    end

    def clauses
      [
        "Este contrato formaliza a contratação vinculada ao pedido #{@order.order_number} e ao negócio #{@deal.title}.",
        "A vigência inicia em #{@contract.starts_on || Date.current} e segue até #{@contract.ends_on || 'a data definida comercialmente'}.",
        "A mensalidade contratada é de #{money(@contract.monthly_cents)} e os reajustes seguem o índice #{@contract.adjustment_index.presence || 'IPCA'}.",
        "A renovação é #{renewal_label}. Alterações comerciais devem ser formalizadas por escrito entre as partes.",
        @contract.notes.presence || 'As partes declaram ciência das condições comerciais, operacionais e de atendimento aplicáveis à contratação.'
      ]
    end

    def contract_title
      "Contrato #{@contract.contract_number}"
    end

    def customer_name
      @contact&.name.presence || @deal.title
    end

    def validity
      "#{@contract.starts_on || 'A definir'} a #{@contract.ends_on || 'A definir'}"
    end

    def renewal_label
      { 'automatic' => 'Automática', 'manual' => 'Manual', 'none' => 'Sem renovação' }.fetch(@contract.renewal_type.to_s, @contract.renewal_type.presence || 'A definir')
    end

    def money(cents)
      ActionController::Base.helpers.number_to_currency(cents.to_i / 100.0, unit: 'R$ ', separator: ',', delimiter: '.')
    end

    def footer(page)
      page.text(48, 38, 'Documento gerado pelo CRM GoPure.', size: 7.2, color: MUTED)
      page.text(402, 38, @contract.contract_number, size: 7.2, bold: true, color: MUTED)
    end

    def logo_data
      path = Rails.root.join('public', 'brand-assets', 'gopure-brand-header.png')
      return nil unless File.exist?(path)

      image = MiniMagick::Image.open(path.to_s)
      image.combine_options { |cmd| cmd.background('white'); cmd.alpha('remove'); cmd.alpha('off') }
      image.format('jpg')
      width, height = image.dimensions
      { bytes: image.to_blob, width: width, height: height }
    rescue StandardError => e
      Rails.logger.warn("JRC CRM contract PDF logo fallback: #{e.message}")
      nil
    end
  end
end
