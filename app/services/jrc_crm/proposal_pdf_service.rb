require 'mini_magick'
module JrcCrm
  class ProposalPdfService
    include CommercialDocumentBrand
    PAGE_WIDTH = 595.28
    PAGE_HEIGHT = 841.89
    GREEN = [0.055, 0.337, 0.231].freeze
    GREEN_2 = [0.070, 0.404, 0.278].freeze
    LIGHT_GREEN = [0.925, 0.965, 0.940].freeze
    GOLD = [0.720, 0.565, 0.278].freeze
    TEXT = [0.075, 0.125, 0.180].freeze
    MUTED = [0.38, 0.43, 0.49].freeze
    WHITE = [1, 1, 1].freeze
    BORDER = [0.86, 0.88, 0.91].freeze

    def initialize(proposal)
      @proposal = proposal
      @deal = proposal.deal
      @contact = proposal.customer_contact
      @pages = []
    end

    def call
      build_cover
      build_solution_and_items
      build_commercial_conditions
      PdfDocument.new(@pages, logo: logo_data).render
    end

    private

    def build_cover
      page = Page.new
      page.fill_rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, WHITE)
      page.fill_rect(0, 0, 12, PAGE_HEIGHT, GREEN)
      page.logo(390, 710, 150, 46)
      page.text(48, 748, company_name.upcase, size: 10, bold: true, color: GREEN)
      page.text(48, 650, 'PROPOSTA COMERCIAL', size: 11, bold: true, color: GREEN_2)
      page.multiline(48, 615, cover_excerpt(@proposal.title, 34, 2), size: 28, bold: true, color: GREEN, width_chars: 34, leading: 34)
      page.multiline(48, 525, cover_excerpt(@proposal.solution_description.presence || 'Seleção de produtos e condições comerciais para formalização do pedido.', 66, 2), size: 12.5, color: MUTED, width_chars: 66, leading: 19)
      page.fill_rect(48, 478, 245, 4, GREEN)
      page.fill_rect(293, 478, 242, 4, GOLD)

      page.fill_rect(48, 325, 487, 124, LIGHT_GREEN)
      page.text(64, 422, 'PREPARADO PARA', size: 8, bold: true, color: MUTED)
      page.text(64, 397, customer_name, size: 15, bold: true, color: TEXT)
      page.text(308, 422, 'PROPOSTA', size: 8, bold: true, color: MUTED)
      page.text(308, 397, @proposal.proposal_number, size: 15, bold: true, color: TEXT)
      page.text(64, 362, 'VALIDADE', size: 8, bold: true, color: MUTED)
      page.text(64, 340, valid_until_text, size: 11, color: TEXT)
      page.text(308, 362, 'RESPONSÁVEL COMERCIAL', size: 8, bold: true, color: MUTED)
      page.text(308, 340, proposal_owner_name, size: 11, bold: true, color: TEXT)

      page.text(48, 64, document_footer, size: 8, color: MUTED)
      page.text(432, 64, (document_gopure?(@proposal.account) ? 'gopure.com.br' : ''), size: 8, bold: true, color: GREEN)
      @pages << page
    end

    def build_solution_and_items
      page = standard_page('Solução e investimento')
      y = 724
      if Page.new.wrapped_lines(@proposal.title, width_chars: 34).size > 2
        page, y = flowing_text(page, y, @proposal.title, 'Título (continuação)', size: 11, width_chars: 82, leading: 16)
        y -= 18
      end
      page, y = ensure_space(page, y, 60, 'Solução (continuação)')
      page.text(48, y, 'Descrição da solução', size: 11, bold: true, color: GREEN_2)
      page, y = flowing_text(page, y - 28, @proposal.solution_description.presence || 'Solução conforme escopo do negócio.',
                            'Solução (continuação)', size: 11, width_chars: 82, leading: 16)
      y -= 24
      items = @proposal.proposal_items.to_a
      loop do
        page, y = ensure_space(page, y, 106, 'Continuação dos produtos')
        page.text(48, y, 'Produtos e serviços', size: 11, bold: true, color: GREEN_2)
        y -= 22
        capacity = [(y - 28 - 70).div(50), 1].max
        draw_items_table(page, items.shift(capacity), y)
        break if items.empty?

        @pages << page
        page = standard_page('Continuação dos produtos')
        y = 724
      end
      @pages << page
    end

    # Reserve the footer before drawing. Long paragraphs flow without truncation.
    def ensure_space(page, y, height, title)
      return [page, y] if y - height >= 70

      @pages << page
      [standard_page(title), 726]
    end

    def flowing_text(page, y, text, title, size:, width_chars:, leading:)
      Page.new.wrapped_lines(text, width_chars: width_chars).each do |line|
        page, y = ensure_space(page, y, leading, title)
        page.text(48, y, line, size: size, color: TEXT)
        y -= leading
      end
      [page, y]
    end

    def cover_excerpt(text, width, count)
      lines = Page.new.wrapped_lines(text, width_chars: width)
      excerpt = lines.first(count)
      excerpt[-1] = "#{excerpt.last[0, width - 3]}..." if lines.size > count
      excerpt.join("\n")
    end

    def company_name
      @proposal.account.name.presence || 'Equipe comercial'
    end

    def document_footer
      document_gopure?(@proposal.account) ? 'Saúde hoje. Mais vida amanhã.' : company_name
    end

    def build_commercial_conditions
      page = standard_page('Condições do pedido')
      y = 726

      page.text(48, y, 'Resumo comercial', size: 12, bold: true, color: GREEN_2)
      y -= 28
      y = commercial_row(page, y, 'Produtos / serviços', money(@proposal.total_cents), bold: false)
      if @proposal.shipping_mode == 'included'
        y = commercial_row(page, y, 'Frete', 'Incluso')
      elsif @proposal.shipping_mode == 'separate' && @proposal.shipping_cents.to_i.positive?
        y = commercial_row(page, y, 'Frete', money(@proposal.shipping_cents))
      end
      y = commercial_row(page, y, 'Total da contratação', money(@proposal.contract_total_cents), bold: true)
      y -= 16

      page, y = ensure_space(page, y, 230, 'Condições (continuação)')
      page.text(48, y, 'Condição de pagamento', size: 12, bold: true, color: GREEN_2)
      y -= 25
      y = commercial_row(page, y, 'Modalidade', payment_condition_label)
      if @proposal.payment_condition == 'down_payment_installments'
        y = commercial_row(page, y, 'Entrada', money(@proposal.down_payment_cents))
        y = commercial_row(page, y, 'Saldo', money(payment_balance_cents))
      end
      y = commercial_row(page, y, 'Parcelamento', installment_plan_label) if @proposal.payment_condition != 'cash'
      y = commercial_row(page, y, 'Forma de pagamento', payment_method_label)
      if @proposal.shipping_mode == 'separate'
        y = commercial_row(page, y, 'Frete no parcelamento', @proposal.shipping_in_installments? ? 'Sim' : 'Não')
      end
      y -= 16

      if @proposal.has_monthly_fee?
        page, y = ensure_space(page, y, 97, 'Condições (continuação)')
        page.text(48, y, 'Recorrência', size: 12, bold: true, color: GREEN_2)
        y -= 25
        y = commercial_row(page, y, 'Mensalidade', "#{money(@proposal.monthly_cents)}/mês")
        y = commercial_row(page, y, 'Vigência', "#{@proposal.term_months} meses")
        y -= 14
      end

      page, y = ensure_space(page, y, 50, 'Observações (continuação)')
      page.text(48, y, 'Observações comerciais', size: 12, bold: true, color: GREEN_2)
      y -= 22
      page, y = flowing_text(page, y, @proposal.commercial_notes.presence || 'Condições sujeitas à validação comercial, cadastral e operacional.',
                              'Observações (continuação)', size: 9.2, width_chars: 92, leading: 14)
      y -= 20

      page, y = ensure_space(page, y, 184, 'Conclusão do pedido')
      page.text(48, y, 'Fluxo para conclusão', size: 12, bold: true, color: GREEN_2)
      y -= 24
      flow = [
        ['1', 'Aprovação', 'Confirmação dos produtos, quantidades, valores, frete e condições comerciais.'],
        ['2', 'Cadastro e crédito', 'Validação cadastral e, quando aplicável, análise de crédito para pagamento parcelado ou em boleto.'],
        ['3', 'Pagamento', payment_flow_text],
        ['4', 'Separação e entrega', 'Confirmação da disponibilidade, faturamento e programação da entrega conforme a condição de frete acordada.']
      ]
      flow.each do |number, title, description|
        page.fill_rect(48, y - 34, 30, 34, GREEN)
        page.text(60, y - 22, number, size: 10, bold: true, color: WHITE)
        page.text(88, y - 18, title, size: 8.8, bold: true, color: TEXT)
        page.multiline(190, y - 13, description, size: 7.8, color: TEXT, width_chars: 56, leading: 10)
        page.line(48, y - 34, 547, y - 34, color: BORDER, width: 0.5)
        y -= 38
      end
      y -= 10
      page, y = ensure_space(page, y, 110, 'Aceite comercial')
      page.text(48, y, 'Aceite comercial', size: 12, bold: true, color: GREEN_2)
      y -= 22
      page.multiline(48, y, 'Ao aprovar esta proposta, o cliente declara estar de acordo com os itens, quantidades, valores e condições comerciais aqui apresentados, ressalvadas as confirmações cadastrais e operacionais previstas.', size: 8.5, color: TEXT, width_chars: 94, leading: 13)
      y -= 55
      page.line(48, y, 270, y, color: MUTED, width: 0.6)
      page.line(315, y, 537, y, color: MUTED, width: 0.6)
      page.text(48, y - 18, customer_name, size: 8, bold: true, color: TEXT)
      page.text(315, y - 18, "#{company_name} - #{proposal_owner_name}", size: 8, bold: true, color: TEXT)
      @pages << page
    end

    def standard_page(title)
      page = Page.new
      page.fill_rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, WHITE)
      page.fill_rect(0, 0, 10, PAGE_HEIGHT, GREEN)
      page.logo(420, 772, 120, 36)
      page.text(48, 796, "#{company_name.upcase} | PROPOSTA COMERCIAL", size: 8, bold: true, color: GREEN)
      page.text(48, 770, title, size: 20, bold: true, color: GREEN)
      page.line(48, 755, 547, 755, color: GREEN_2, width: 1)
      page.text(48, 38, document_footer, size: 7.2, color: MUTED)
      page.text(405, 38, "#{@proposal.proposal_number} | #{customer_name.upcase}", size: 6.8, bold: true, color: MUTED)
      page
    end

    def draw_items_table(page, items, y)
      widths = [150, 62, 35, 64, 57, 57, 74]
      x = 48
      page.fill_rect(x, y - 28, widths.sum, 28, GREEN_2)
      headers = ['Produto / Serviço', 'Cobrança', 'Qtd.', 'Preço', 'Setup', 'Desc.', 'Total inicial']
      cx = x
      headers.each_with_index do |header, idx|
        page.text(cx + 4, y - 18, header, size: 6.7, bold: true, color: WHITE)
        cx += widths[idx]
      end
      y -= 28

      if items.empty?
        page.text(x + 8, y - 22, 'Nenhum produto adicionado.', size: 10, color: MUTED)
        return
      end

      items.each_with_index do |item, idx|
        row_h = 50
        page.fill_rect(x, y - row_h, widths.sum, row_h, idx.even? ? WHITE : [0.976, 0.982, 0.989])
        page.line(x, y - row_h, x + widths.sum, y - row_h, color: BORDER, width: 0.6)
        page.text(x + 4, y - 17, truncate(item.name_snapshot, 24), size: 7.8, bold: true, color: TEXT)
        if item.description_snapshot.present?
          page.text(x + 4, y - 31, truncate(item.description_snapshot, 28), size: 6.3, color: MUTED)
        end
        if item.included_quantity.to_f.positive?
          page.text(x + 4, y - 43, truncate("Franquia #{item.included_quantity} #{item.included_unit}", 30), size: 5.8, color: MUTED)
        end
        cx = x + widths[0]
        page.text(cx + 4, y - 26, billing_label(item.billing_model), size: 6.6, color: TEXT)
        cx += widths[1]
        page.text(cx + 4, y - 26, item.quantity.to_s, size: 7.2, color: TEXT)
        cx += widths[2]
        page.text(cx + 3, y - 26, money(item.unit_price_cents), size: 6.4, color: TEXT)
        cx += widths[3]
        page.text(cx + 3, y - 26, money(item.setup_fee_cents), size: 6.4, color: TEXT)
        cx += widths[4]
        page.text(cx + 3, y - 26, money(item.applied_discount_cents), size: 6.4, color: TEXT)
        cx += widths[5]
        page.text(cx + 3, y - 26, money(item.initial_total_cents), size: 6.4, bold: true, color: TEXT)
        y -= row_h
      end
    end

    def commercial_row(page, y, label, value, bold: false)
      page.text(58, y, label, size: bold ? 11 : 10, bold: bold, color: bold ? GREEN : TEXT)
      page.text(380, y, value, size: bold ? 11 : 10, bold: bold, color: bold ? GREEN : TEXT)
      page.line(48, y - 10, 547, y - 10, color: BORDER, width: 0.5)
      y - 29
    end

    def logo_data
      path = document_logo_path(@proposal.account)
      return nil unless File.exist?(path)

      image = MiniMagick::Image.open(path.to_s)
      image.combine_options do |cmd|
        cmd.background 'white'
        cmd.alpha 'remove'
        cmd.alpha 'off'
      end
      image.format('jpg')
      width, height = image.dimensions
      { bytes: image.to_blob, width: width, height: height }
    rescue StandardError => e
      Rails.logger.warn("JRC CRM PDF logo fallback: #{e.message}")
      nil
    end

    def customer_name
      @contact&.name.presence || @deal&.title.presence || 'Cliente'
    end

    def valid_until_text
      (@proposal.valid_until || 15.days.from_now.to_date).strftime('%d/%m/%Y')
    end

    def payment_condition_label
      { 'cash' => 'À vista', 'down_payment_installments' => 'Entrada + parcelas', 'installments' => 'Parcelado sem entrada' }.fetch(@proposal.payment_condition, @proposal.payment_condition.presence || 'A definir')
    end

    def payment_flow_text
      case @proposal.payment_condition
      when 'cash' then 'Pagamento integral conforme a forma de pagamento definida na proposta.'
      when 'down_payment_installments' then "Pagamento da entrada e do saldo em #{@proposal.installments_count} parcela(s), conforme as condições desta proposta."
      else "Pagamento em #{@proposal.installments_count} parcela(s), conforme as condições desta proposta."
      end
    end

    def proposal_owner_name
      @proposal.owner&.name.presence || @deal&.owner&.name.presence || 'Equipe comercial'
    end

    def payment_method_label
      { 'boleto' => 'Boleto', 'pix' => 'PIX', 'transferencia' => 'Transferência', 'cartao' => 'Cartão' }.fetch(@proposal.payment_method.to_s, @proposal.payment_method.presence || 'A definir')
    end

    def payment_balance_cents
      [@proposal.payable_base_cents - @proposal.down_payment_cents.to_i, 0].max
    end

    def installment_plan_label
      values = @proposal.installment_plan_cents
      return 'Não se aplica' if values.empty?
      groups = values.tally
      return "#{values.size} x #{money(values.first)}" if groups.size == 1

      groups.map { |value, quantity| "#{quantity} x #{money(value)}" }.join(' + ')
    end

    def billing_label(value)
      {
        'one_time' => 'Única',
        'monthly' => 'Mensal',
        'annual' => 'Anual',
        'usage' => 'Por uso'
      }.fetch(value.to_s, value.to_s)
    end

    def renewal_label
      {
        'automatic' => 'automática',
        'manual' => 'manual',
        'none' => 'sem renovação'
      }.fetch(@proposal.renewal_type.to_s, @proposal.renewal_type.to_s)
    end

    def percentage(value)
      ActionController::Base.helpers.number_to_percentage(value.to_f, precision: 2, strip_insignificant_zeros: true)
    end

    def money(cents)
      ActionController::Base.helpers.number_to_currency(cents.to_i / 100.0, unit: 'R$ ', separator: ',', delimiter: '.')
    end

    def truncate(value, length)
      text = value.to_s
      text.length > length ? "#{text[0, length - 1]}…" : text
    end

    class Page
      attr_reader :commands

      def initialize
        @commands = ''.b
      end

      def text(x, y, value, size: 11, bold: false, color: TEXT)
        return if value.blank?

        @commands << color_cmd(color)
        @commands << "BT /#{bold ? 'F2' : 'F1'} #{size} Tf #{fmt(x)} #{fmt(y)} Td (#{escape(value)}) Tj ET\n".b
      end

      def wrapped_lines(value, width_chars: 80)
        wrap(value.to_s, width_chars)
      end

      def multiline(x, y, value, size: 11, bold: false, color: TEXT, width_chars: 80, leading: 16)
        lines = wrap(value.to_s, width_chars)
        lines.each do |line|
          text(x, y, line, size: size, bold: bold, color: color)
          y -= leading
        end
        y
      end

      def fill_rect(x, y, width, height, color)
        @commands << color_cmd(color)
        @commands << "#{fmt(x)} #{fmt(y)} #{fmt(width)} #{fmt(height)} re f\n".b
      end

      def line(x1, y1, x2, y2, color:, width: 1)
        @commands << stroke_color_cmd(color)
        @commands << "#{fmt(width)} w #{fmt(x1)} #{fmt(y1)} m #{fmt(x2)} #{fmt(y2)} l S\n".b
      end

      def logo(x, y, width, height)
        @commands << "q #{fmt(width)} 0 0 #{fmt(height)} #{fmt(x)} #{fmt(y)} cm /Logo Do Q\n".b
      end

      private

      def wrap(text, max_chars)
        text.split("\n").flat_map do |paragraph|
          words = paragraph.split(/\s+/).flat_map { |word| word.scan(/.{1,#{max_chars}}/) }
          next [''] if words.empty?

          words.each_with_object(['']) do |word, lines|
            candidate = [lines.last, word].reject(&:blank?).join(' ')
            if candidate.length > max_chars && lines.last.present?
              lines << word
            else
              lines[-1] = candidate
            end
          end
        end
      end

      def escape(value)
        value.to_s.encode(Encoding::Windows_1252, invalid: :replace, undef: :replace, replace: '?')
             .gsub(/[\\()]/) { |char| "\\#{char}" }
             .force_encoding(Encoding::BINARY)
      end

      def color_cmd(color)
        "#{color.map { |v| fmt(v) }.join(' ')} rg\n".b
      end

      def stroke_color_cmd(color)
        "#{color.map { |v| fmt(v) }.join(' ')} RG\n".b
      end

      def fmt(value)
        format('%.3f', value.to_f).sub(/\.0+$/, '').sub(/(\.\d*?)0+$/, '\\1')
      end
    end

    class PdfDocument
      def initialize(pages, logo: nil)
        @pages = pages
        @logo = logo
      end

      def render
        objects = []
        add = ->(body) { objects << body.b; objects.length }

        catalog_id = add.call('')
        pages_id = add.call('')
        font_regular_id = add.call('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>')
        font_bold_id = add.call('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>')
        logo_id = @logo ? add.call(logo_object(@logo)) : nil

        page_ids = []
        @pages.each do |page|
          content = page.commands.dup
          content.gsub!('/Logo Do'.b, ''.b) unless logo_id
          content_id = add.call(stream_object(content))
          resources = "<< /Font << /F1 #{font_regular_id} 0 R /F2 #{font_bold_id} 0 R >>"
          resources += " /XObject << /Logo #{logo_id} 0 R >>" if logo_id
          resources += ' >>'
          page_id = add.call("<< /Type /Page /Parent #{pages_id} 0 R /MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] /Resources #{resources} /Contents #{content_id} 0 R >>")
          page_ids << page_id
        end

        objects[catalog_id - 1] = "<< /Type /Catalog /Pages #{pages_id} 0 R >>".b
        objects[pages_id - 1] = "<< /Type /Pages /Count #{page_ids.length} /Kids [#{page_ids.map { |id| "#{id} 0 R" }.join(' ')}] >>".b

        out = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b
        offsets = [0]
        objects.each_with_index do |body, index|
          offsets << out.bytesize
          out << "#{index + 1} 0 obj\n".b << body << "\nendobj\n".b
        end
        xref = out.bytesize
        out << "xref\n0 #{objects.length + 1}\n".b
        out << "0000000000 65535 f \n".b
        offsets.drop(1).each { |offset| out << format("%010d 00000 n \n", offset).b }
        out << "trailer\n<< /Size #{objects.length + 1} /Root #{catalog_id} 0 R >>\nstartxref\n#{xref}\n%%EOF\n".b
        out
      end

      private

      def stream_object(content)
        "<< /Length #{content.bytesize} >>\nstream\n".b + content + "\nendstream".b
      end

      def logo_object(logo)
        bytes = logo[:bytes].dup.force_encoding(Encoding::BINARY)
        header = "<< /Type /XObject /Subtype /Image /Width #{logo[:width]} /Height #{logo[:height]} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{bytes.bytesize} >>\nstream\n".b
        header + bytes + "\nendstream".b
      end
    end
  end
end
