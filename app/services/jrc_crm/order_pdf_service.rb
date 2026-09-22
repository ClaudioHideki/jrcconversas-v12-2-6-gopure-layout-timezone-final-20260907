require 'mini_magick'

module JrcCrm
  class OrderPdfService
    P = ProposalPdfService
    def initialize(order)
      @order = order
      @contact = order.contact
      @snapshot = order.snapshot || {}
      @items = order.order_items.to_a
    end

    def call
      pages = [summary_page] + @items.drop(7).each_slice(16).map { |items| items_page(items) }
      P::PdfDocument.new(pages + [financial_page, operation_page], logo: logo_data).render
    end

    private

    def summary_page
      page = base_page('PEDIDO COMERCIAL')
      page.text(48, 716, @order.order_number, size: 24, bold: true, color: P::GREEN)
      page.text(48, 690, 'Documento comercial de confirmação do pedido', size: 10, color: P::MUTED)
      page.fill_rect(48, 560, 499, 100, P::LIGHT_GREEN)
      info(page, 630, 'CLIENTE', customer_name)
      info(page, 598, 'PROPOSTA DE ORIGEM', @order.proposal&.proposal_number || 'Pedido direto')
      info(page, 566, 'RESPONSÁVEL', @order.owner&.name || 'Equipe comercial')

      page.text(48, 528, 'Produtos e serviços', size: 12, bold: true, color: P::GREEN_2)
      y = 505
      @items.first(7).each do |item|
        page.text(52, y, item.name.to_s[0, 38], size: 8.2, bold: true, color: P::TEXT)
        page.text(300, y, "#{fmt_qty(item.quantity)} x #{money(item.unit_cents)}", size: 8, color: P::TEXT)
        page.text(450, y, money(item.one_time_cents), size: 8, bold: true, color: P::TEXT)
        page.text(300, y - 11, "MRR: #{money(item.recurring_cents)}/mês · #{term_label(item)}", size: 7, color: P::MUTED)
        page.line(48, y - 16, 547, y - 16, color: P::BORDER, width: 0.5)
        y -= 30
      end
      page.text(48, 265, 'Valores iniciais e recorrentes discriminados no resumo financeiro.', size: 9, color: P::MUTED)
      footer(page)
      page
    end

    def items_page(items)
      page = base_page('PRODUTOS E SERVIÇOS (CONTINUAÇÃO)')
      y = 715
      items.each do |item|
        page.text(48, y, item.name.to_s[0, 70], size: 9, bold: true, color: P::TEXT)
        page.text(48, y - 15, "#{fmt_qty(item.quantity)} x #{money(item.unit_cents)} | Inicial: #{money(item.one_time_cents)} | MRR: #{money(item.recurring_cents)}/mês", size: 8, color: P::TEXT)
        page.text(48, y - 28, term_label(item), size: 8, color: P::MUTED)
        y -= 38
      end
      footer(page)
      page
    end

    def term_label(item)
      return '' unless item.recurring_cents.positive?

      months = item.snapshot['contract_term_months'].to_i
      months.positive? ? "#{months} meses" : 'Prazo não definido'
    end

    def financial_page
      page = base_page('RESUMO FINANCEIRO')
      y = commercial_row(page, 710, 'Subtotal único (após desconto dos itens)', money(@order.products_cents))
      y = commercial_row(page, y, 'Desconto geral', "- #{money(@order.discount_cents)}")
      y = commercial_row(page, y, 'Frete', money(@order.shipping_cents))
      y = commercial_row(page, y, 'Impostos', money(snap('taxes_cents', 0)))
      y = commercial_row(page, y, 'Acréscimos', money(snap('surcharge_cents', 0)))
      y = commercial_row(page, y, 'VALOR INICIAL', money(@order.total_cents), true)
      y = commercial_row(page, y, 'MRR', "#{money(@order.monthly_cents)}/mês", true)
      if snap('contract_total_cents')
        y = commercial_row(page, y, 'Recorrência contratada', money(snap('contracted_recurring_cents')))
        commercial_row(page, y, 'Valor contratual global', money(snap('contract_total_cents')), true)
      end
      footer(page)
      page
    end

    def operation_page
      page = base_page('CONDIÇÕES E OPERAÇÃO')
      y = 718
      page.text(48, y, 'Condições financeiras', size: 12, bold: true, color: P::GREEN_2); y -= 30
      y = commercial_row(page, y, 'Forma de pagamento', payment_label)
      y = commercial_row(page, y, 'Parcelas', @order.installments_count.to_i.to_s)
      y = commercial_row(page, y, '1º vencimento', snap('first_due_date', 'A definir'))
      y -= 12
      if @order.implementation_items.any? || (@snapshot['financial_version'].to_i < 2 && snap('send_to_implementation'))
      page.text(48, y, 'Implantação e entrega', size: 12, bold: true, color: P::GREEN_2); y -= 30
      y = commercial_row(page, y, 'Previsão de ativação', snap('activation_date', 'A definir'))
      y = commercial_row(page, y, 'Responsável interno', snap('operation_owner_name', @order.owner&.name || 'A definir'))
      y = commercial_row(page, y, 'Equipe', snap('implementation_team', 'Time de Implantação'))
      y = commercial_row(page, y, 'Prioridade', snap('priority', 'Normal'))
      end
      y -= 12
      page.text(48, y, 'Observações', size: 12, bold: true, color: P::GREEN_2); y -= 25
      page.multiline(48, y, @order.notes.presence || snap('operation_notes', 'Sem observações adicionais.'), size: 9, color: P::TEXT, width_chars: 92, leading: 14)
      page.text(48, 120, 'Aceite do pedido', size: 11, bold: true, color: P::GREEN_2)
      page.line(48, 82, 260, 82, color: P::MUTED, width: 0.6)
      page.line(330, 82, 542, 82, color: P::MUTED, width: 0.6)
      page.text(48, 65, customer_name, size: 8, bold: true, color: P::TEXT)
      page.text(330, 65, company_signature, size: 8, bold: true, color: P::TEXT)
      footer(page)
      page
    end

    def base_page(title)
      page = P::Page.new
      page.fill_rect(0, 0, P::PAGE_WIDTH, P::PAGE_HEIGHT, P::WHITE)
      page.fill_rect(0, 0, 10, P::PAGE_HEIGHT, P::GREEN)
      page.logo(420, 772, 120, 36)
      page.text(48, 796, "#{company_name.upcase} | PEDIDOS / VENDAS", size: 8, bold: true, color: P::GREEN)
      page.text(48, 770, title, size: 20, bold: true, color: P::GREEN)
      page.line(48, 755, 547, 755, color: P::GREEN_2, width: 1)
      page
    end

    def info(page, y, label, value)
      page.text(62, y, label, size: 7.2, bold: true, color: P::MUTED)
      page.text(205, y, value.to_s, size: 9.2, bold: true, color: P::TEXT)
    end

    def commercial_row(page, y, label, value, bold=false)
      page.text(58, y, label, size: bold ? 11 : 9.5, bold: bold, color: bold ? P::GREEN : P::TEXT)
      page.text(385, y, value, size: bold ? 11 : 9.5, bold: bold, color: bold ? P::GREEN : P::TEXT)
      page.line(48, y - 9, 547, y - 9, color: P::BORDER, width: 0.5)
      y - 28
    end

    def footer(page)
      page.text(48, 38, snap('footer_text', company_name), size: 7.2, color: P::MUTED)
      page.text(430, 38, @order.order_number, size: 7, bold: true, color: P::MUTED)
    end

    def logo_data
      candidates = ['public/brand-assets/logo.png']
      candidates.unshift('public/brand-assets/gopure-brand-header.png') if @order.account.name.to_s.downcase.delete(' ') == 'gopure'
      path = candidates.map { |x| Rails.root.join(x) }.find { |x| File.exist?(x) }
      return nil unless path
      image = MiniMagick::Image.open(path.to_s)
      image.combine_options { |cmd| cmd.background 'white'; cmd.alpha 'remove'; cmd.alpha 'off' }
      image.format('jpg'); w,h=image.dimensions
      { bytes: image.to_blob, width: w, height: h }
    rescue StandardError => e
      Rails.logger.warn("JRC CRM order PDF logo fallback: #{e.message}"); nil
    end

    def snap(key, fallback=nil); @snapshot[key].presence || @snapshot[key.to_sym].presence || fallback; end
    def company_name; snap('company_name', @order.business_unit&.name.presence || @order.account.name); end
    def company_signature; "#{company_name} - #{@order.owner&.name || 'Comercial'}"; end
    def customer_name; @contact&.name.presence || @order.deal&.title.presence || snap('customer_name', 'Cliente'); end
    def payment_label
      labels = { 'boleto' => 'Boleto', 'pix' => 'Pix', 'credit_card' => 'Cartão de crédito', 'card' => 'Cartão',
                 'bank_transfer' => 'Transferência bancária', 'transfer' => 'Transferência', 'cash' => 'À vista',
                 'installments' => 'Parcelado', 'recurring' => 'Recorrente', 'monthly' => 'Mensal', 'annual' => 'Anual' }
      [@order.payment_method, @order.payment_condition].filter_map { |value| labels.fetch(value, value).presence }.join(' · ').presence || 'A definir'
    end
    def money(cents); ActionController::Base.helpers.number_to_currency(cents.to_i / 100.0, unit: 'R$ ', separator: ',', delimiter: '.'); end
    def fmt_qty(q); q.to_f % 1 == 0 ? q.to_i : q.to_f; end
  end
end
