module Api
  module V1
    module Accounts
      module Crm
        class ProposalsController < BaseController
          include JrcCrm::CorporateProposalParameters
          before_action :set_proposal, only: [
            :show, :update, :destroy, :send_proposal, :pdf, :accept, :reject,
            :cancel, :duplicate, :version_history, :prepare_historical, :request_approval, :approve, :convert_to_order
          ]
          before_action :ensure_unlocked_proposal!, only: [:update, :destroy, :request_approval, :approve, :accept, :reject, :cancel]

          around_action :lock_proposal_mutation, only: %i[update destroy request_approval approve accept reject cancel send_proposal]

          def index
            proposals = visible_to_current_user(crm_scope.jrc_crm_proposals)
            proposals = proposals.where(deal_id: params[:deal_id]) if params[:deal_id].present?
            proposals = proposals.where(status: params[:status]) if params[:status].present?
            proposals = proposals.where(owner_id: params[:owner_id]) if params[:owner_id].present?

            render json: proposals.includes(:owner, :deal, { events: :user }, { business_unit: :operating_company }, proposal_items: :product)
                                  .order(updated_at: :desc)
                                  .map { |proposal| serialize(proposal) }
          end

          def show
            render json: serialize(@proposal)
          end

          def create
            deal = visible_to_current_user(crm_scope.jrc_crm_deals).find(params[:deal_id]) if params[:deal_id].present?
            company = contact = nil
            unless deal
              authorize :directory, :access?, policy_class: JrcCustomers::DirectoryPolicy
              company = corporate_records(:master_companies).find(params[:company_id]) if params[:company_id].present?
              contact = crm_scope.contacts.find(params[:contact_id]) if params[:contact_id].present?
              authorize contact, :show? if contact
            end
            unit = crm_scope.jrc_crm_business_units.find(params[:business_unit_id]) if params[:business_unit_id].present?
            authorize_operating_unit!(unit)
            attributes = params[:proposal].present? ? proposal_params.to_h.except('owner_id') : {}
            attributes.delete('title') if attributes['title'].blank?
            proposal = build_corporate_proposal(deal, company, contact, unit, attributes)
            render json: serialize(proposal), status: :created
          rescue ActiveRecord::RecordInvalid, JrcCrm::CommercialFinancials::InvalidTerms => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          def update
            attributes = corporate_proposal_attributes
            validate_proposal_owner!(attributes[:owner_id]) if attributes[:owner_id].present?
            normalize_payment_attributes!(attributes)
            attributes.except!(:implementation_cents, :monthly_cents, :subtotal_cents, :total_cents) if @proposal.proposal_items.exists?

            if @proposal.update(attributes)
              commercial_changes = @proposal.saved_changes.keys - %w[updated_at]
              @proposal.reset_approvals! if commercial_changes.any?
              @proposal.recalculate_totals!
              JrcApprovals::CommercialInvalidation.call(resource: @proposal.reload, user: Current.user)
              audit_event!('updated', 'Proposta atualizada no CRM')
              render json: serialize(@proposal.reload)
            else
              render json: { errors: @proposal.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            authorize @proposal, :destroy?, policy_class: JrcCrm::ProposalPolicy
            if @proposal.sales_orders.exists?
              render json: { errors: ['A proposta possui pedido vinculado e não pode ser excluída.'], code: 'PROPOSAL_HAS_DEPENDENCIES' }, status: :conflict
              return
            end
            snapshot = @proposal.attributes.except('public_token_digest', 'accepted_from_ip', 'accepted_user_agent')
            @proposal.destroy!
            JrcCrm::AuditEvent.create!(account: crm_scope, actor_type: 'User', actor_id: Current.user.id,
                                       event_type: 'proposal_deleted', resource_type: 'JrcCrm::Proposal', resource_id: @proposal.id,
                                       from_value: snapshot, to_value: {}, metadata: { proposal_number: @proposal.proposal_number })
            head :no_content
          rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
            render json: { errors: ['A proposta possui vínculos que impedem a exclusão.'], code: 'PROPOSAL_HAS_DEPENDENCIES' }, status: :conflict
          end

          def duplicate
            authorize @proposal, :create?, policy_class: JrcCrm::ProposalPolicy
            revised = JrcCrm::ProposalRevisionService.new(proposal: @proposal, actor: Current.user).call
            render json: serialize(revised), status: :created
          rescue ActiveRecord::RecordInvalid, ArgumentError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          def version_history
            version_ids = JrcCrm::ProposalVersionHistory.new(@proposal).ids
            proposals = visible_to_current_user(crm_scope.jrc_crm_proposals)
                        .where(id: version_ids).order(:version_number, :id)
            render json: proposals.map { |proposal| serialize_version(proposal) }
          end

          def prepare_historical
            authorize @proposal, :send_proposal?, policy_class: JrcCrm::ProposalPolicy
            raise ArgumentError, 'A proposta está vigente. Utilize o envio normal.' unless @proposal.historical?

            JrcCrm::ProposalDocumentArchive.new(@proposal, actor: Current.user).capture!
            render json: { public_url: JrcCrm::HistoricalProposalLink.url(@proposal, base_url: request.base_url) }
          rescue ArgumentError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          def request_approval
            unless @proposal.proposal_items.exists?
              render json: { errors: ['Adicione ao menos um produto ou serviço antes de solicitar aprovação.'] },
                     status: :unprocessable_entity
              return
            end

            @proposal.recalculate_totals!
            @proposal.update!(
              status: 'pending_approval',
              approval_status: 'pending',
              commercial_approval_status: 'pending',
              financial_approval_status: financial_approval_required? ? 'pending' : 'not_required',
              technical_approval_status: technical_approval_required? ? 'pending' : 'not_required'
            )
            audit_event!('approval_requested', 'Aprovação interna solicitada')
            render json: serialize(@proposal.reload)
          end

          def approve
            ensure_crm_admin!
            type = params[:approval_type].to_s
            if JrcCrm::ProposalProfile.commercial_only?(@proposal)
              raise Pundit::NotAuthorizedError if @proposal.owner_id == Current.user.id
              raise ActionController::BadRequest, 'Somente aprovação comercial é aplicável.' unless type == 'commercial'
            end
            column = {
              'commercial' => :commercial_approval_status,
              'financial' => :financial_approval_status,
              'technical' => :technical_approval_status
            }[type]
            raise ActionController::BadRequest, 'Tipo de aprovação inválido' unless column

            decision = params[:decision].to_s
            raise ActionController::BadRequest, 'Decisão de aprovação inválida' unless %w[approved rejected].include?(decision)

            @proposal.update!(column => decision)
            finalize_approval_state!
            audit_event!('approval_updated', "Aprovação #{type} atualizada")
            render json: serialize(@proposal.reload)
          end

          def pdf
            pdf_data = if @proposal.historical?
                         JrcCrm::ProposalDocumentArchive.new(@proposal, actor: Current.user).capture!.download
                       else
                         JrcCrm::ProposalPdfService.new(@proposal).call
                       end
            audit_event!('pdf_generated', 'PDF da proposta gerado no CRM')
            send_data pdf_data,
                      filename: "#{@proposal.proposal_number.parameterize}-#{@proposal.title.parameterize.presence || @proposal.id}.pdf",
                      type: 'application/pdf',
                      disposition: ActiveModel::Type::Boolean.new.cast(params[:download]) ? 'attachment' : 'inline'
          rescue ArgumentError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          def send_proposal
            historical = ActiveModel::Type::Boolean.new.cast(params[:historical])
            authorize @proposal, :send_proposal?, policy_class: JrcCrm::ProposalPolicy
            if !historical && @proposal.historical?
              render json: { errors: ['Proposta sem vigência. Escolha Reenviar proposta (somente consulta) ou Editar e criar nova versão.'] },
                     status: :unprocessable_entity
              return
            end

            unless @proposal.proposal_items.exists?
              render json: { errors: ['Adicione ao menos um produto ou serviço antes de enviar a proposta.'] },
                     status: :unprocessable_entity
              return
            end

            @proposal.recalculate_totals! unless historical
            if @proposal.approval_status == 'pending'
              render json: { errors: ['A proposta ainda possui aprovações pendentes.'] }, status: :unprocessable_entity
              return
            end
            if @proposal.approval_status == 'rejected'
              render json: { errors: ['A proposta foi reprovada e não pode ser enviada.'] }, status: :unprocessable_entity
              return
            end
            if approval_required? && @proposal.approval_status != 'approved'
              render json: { errors: ['Os descontos ou requisitos técnicos exigem aprovação interna antes do envio.'] },
                     status: :unprocessable_entity
              return
            end

            result = JrcCrm::ProposalDeliveryService.new(
              proposal: @proposal,
              actor: Current.user,
              channel: params[:channel].presence || 'auto',
              base_url: request.base_url,
              idempotency_key: params[:idempotency_key],
              historical: historical,
              historical_url: params[:historical_url]
            ).call(delivery: recipient_delivery_params)

            render json: {
              message: 'Proposta enviada com sucesso',
              proposal: serialize(result[:proposal]),
              delivery: {
                conversation_id: result[:conversation].id,
                conversation_display_id: result[:conversation].display_id,
                inbox_id: result[:conversation].inbox_id,
                message_id: result[:message].id,
                channel: result.fetch(:channel)
              }
            }
          rescue Pundit::NotAuthorizedError
            head :forbidden
          rescue ActiveRecord::RecordNotFound
            head :not_found
          rescue JrcApprovals::Error => e
            render json: { error: e.code, code: e.code }, status: :conflict
          rescue StandardError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          def accept
            name = params[:accepted_by_name].presence || Current.user.name
            document = params[:accepted_by_document].to_s.strip
            if name.blank? || document.blank?
              render json: { errors: ['Informe o nome completo e o CPF ou documento do signatário.'] },
                     status: :unprocessable_entity
              return
            end

            @proposal.accept_by_customer!(
              name: name,
              document: document,
              remote_ip: request.remote_ip,
              user_agent: request.user_agent
            )
            audit_event!('accepted', 'Proposta aceita internamente com evidência digital')
            lifecycle = JrcCrm::AcceptedProposalLifecycleService.new(
              proposal: @proposal.reload,
              actor: Current.user
            ).call
            render json: {
              message: 'Proposta aceita',
              proposal: serialize(@proposal.reload),
              sales_order: lifecycle[:order] && {
                id: lifecycle[:order].id,
                order_number: lifecycle[:order].order_number,
                status: lifecycle[:order].status
              },
              lifecycle_warnings: lifecycle[:warnings],
              lifecycle_error: lifecycle[:success] ? nil : lifecycle[:error]
            }
          end

          def reject
            if @proposal.accepted?
              render json: { errors: ['Uma proposta aceita não pode ser rejeitada. Duplique-a para criar uma nova versão.'] },
                     status: :unprocessable_entity
              return
            end

            @proposal.update!(status: 'rejected', rejected_at: Time.current)
            audit_event!('rejected', 'Proposta rejeitada internamente')
            render json: { message: 'Proposta rejeitada', proposal: serialize(@proposal.reload) }
          end

          def cancel
            if @proposal.accepted?
              render json: { errors: ['Uma proposta aceita não pode ser cancelada. Duplique-a para criar uma nova versão.'] },
                     status: :unprocessable_entity
              return
            end

            @proposal.update!(status: 'canceled', canceled_at: Time.current)
            audit_event!('canceled', 'Proposta cancelada')
            render json: { message: 'Proposta cancelada', proposal: serialize(@proposal.reload) }
          end

          def convert_to_order
            order = JrcCrm::ProposalToOrderService.new(proposal: @proposal, actor: Current.user).call
            render json: { id: order.id, order_number: order.order_number, status: order.status, total_cents: order.total_cents }, status: :created
          rescue JrcApprovals::Error => e
            render json: { error: e.code, code: e.code }, status: :conflict
          rescue StandardError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          private

          def lock_proposal_mutation
            @proposal.with_lock do
              if action_name != 'send_proposal' && @proposal.locked_for_editing?
                render json: { errors: ['Esta versão está bloqueada para preservar o histórico. Use Editar e criar nova versão.'] },
                       status: :unprocessable_entity
              else
                yield
              end
            end
          end

          def set_proposal
            @proposal = visible_to_current_user(crm_scope.jrc_crm_proposals).includes(
              :owner, :deal, { events: :user }, { business_unit: :operating_company }, proposal_items: :product
            ).find(params[:id])
          end

          def ensure_unlocked_proposal!
            return unless @proposal.locked_for_editing?

            render json: { errors: ['Esta versão está bloqueada para preservar o histórico. Use Editar e criar nova versão.'] },
                   status: :unprocessable_entity
          end

          def serialize(proposal)
            policy = JrcCrm::ProposalPolicy.new({ account: crm_scope, user: Current.user, account_user: Current.account_user }, proposal)
            JrcCrm::ProposalSerializer.new(proposal, base_url: request.base_url).as_json.merge(
              version_actions: { revise: policy.show? && policy.create?, resend: policy.send_proposal?, history: policy.show? }
            )
          end

          def serialize_version(proposal)
            events = proposal.events.includes(:user).order(:id).map do |event|
              { id: event.id, type: event.event_type, description: event.description, created_at: event.created_at,
                user: event.user && { id: event.user.id, name: event.user.name } }
            end
            document_available = proposal.sent_at.nil? || JrcCrm::ProposalDocumentArchive.new(proposal).blob.present?
            serialize(proposal).merge(document_available: document_available, events: events)
          end

          def recipient_delivery_params
            return unless params.key?(:delivery)

            params.require(:delivery).permit(:contact_id, :inbox_id, :content, template_params: {}).to_h
          end

          def audit_event!(event_type, description)
            @proposal.events.create!(
              account_id: crm_scope.id,
              event_type: event_type,
              user_id: Current.user&.id,
              description: description
            )
          end

          def approval_required?
            commercial_approval_required? || financial_approval_required? || technical_approval_required?
          end

          def commercial_approval_required?
            JrcCrm::ProposalApprovalRequirements.new(@proposal).commercial?
          end

          def financial_approval_required?
            JrcCrm::ProposalApprovalRequirements.new(@proposal).financial?
          end

          def technical_approval_required?
            JrcCrm::ProposalApprovalRequirements.new(@proposal).technical?
          end

          def general_discount_percent
            return 0.0 if @proposal.subtotal_cents.to_i.zero?

            (@proposal.discount_cents.to_f / @proposal.subtotal_cents.to_i) * 100
          end

          def item_discount_percent(item)
            return 0.0 if item.gross_line_total_cents.zero?

            (item.applied_discount_cents.to_f / item.gross_line_total_cents) * 100
          end

          def finalize_approval_state!
            statuses = [
              @proposal.commercial_approval_status,
              @proposal.financial_approval_status,
              @proposal.technical_approval_status
            ]
            if statuses.include?('rejected')
              @proposal.update!(approval_status: 'rejected')
            elsif statuses.all? { |status| %w[approved not_required].include?(status) }
              @proposal.update!(approval_status: 'approved', status: 'draft')
              audit_event!('approved', 'Aprovada internamente — pronta para envio')
            else
              @proposal.update!(approval_status: 'pending', status: 'pending_approval')
            end
          end

          def validate_proposal_owner!(owner_id)
            user = crm_scope.users.find_by(id: owner_id)
            raise Pundit::NotAuthorizedError unless user
            raise Pundit::NotAuthorizedError unless crm_admin? || user.id == @proposal.owner_id
          end

          def normalize_payment_attributes!(attributes)
            if JrcCrm::ProposalProfile.commercial_only?(@proposal) && !@proposal.proposal_items.exists? && attributes.key?(:monthly_cents)
              attributes[:has_monthly_fee] = attributes[:monthly_cents].to_i.positive?
            end
            condition = attributes[:payment_condition].presence || @proposal.payment_condition
            case condition
            when 'cash'
              attributes[:down_payment_cents] = 0
              attributes[:installments_count] = 1
            when 'installments'
              attributes[:down_payment_cents] = 0
            end
            attributes[:monthly_cents] = 0 if attributes.key?(:has_monthly_fee) && !ActiveModel::Type::Boolean.new.cast(attributes[:has_monthly_fee])
            attributes[:shipping_cents] = 0 if attributes[:shipping_mode].present? && attributes[:shipping_mode] != 'separate'
          end

          def proposal_params
            params.require(:proposal).permit(
              :title, :discount_cents,
              :public_token_expires_at, :solution_description, :implementation_cents,
              :monthly_cents, :valid_until, :term_months, :commercial_notes,
              :next_steps, :notes, :customer_notes, :issuer_company_name,
              :issuer_tax_id, :issuer_unit, :payment_method, :billing_day,
              :first_billing_days, :taxes_included, :annual_adjustment_index,
              :renewal_type, :cancellation_penalty_percent, :follow_up_enabled,
              :follow_up_days, :owner_id, :shipping_cents, :shipping_mode, :payment_condition,
              :down_payment_cents, :installments_count, :has_monthly_fee, :shipping_in_installments
            )
          end
        end
      end
    end
  end
end
