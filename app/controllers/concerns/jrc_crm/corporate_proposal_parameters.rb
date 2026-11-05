module JrcCrm::CorporateProposalParameters
  def creation_options
    boundary = JrcCrm::OrganizationalVisibility.new(account: crm_scope, user: Current.user,
                                                    relation: JrcCrm::Proposal.where(account_id: crm_scope.id), include_company: false)
    units = crm_scope.jrc_crm_business_units.where(active: true)
    allowed_ids = boundary.allowed_business_unit_ids
    units = units.where(id: allowed_ids) unless allowed_ids.nil?
    render json: { business_units: units.includes(:operating_company).order(:name).map do |unit|
      {
        id: unit.id, name: [unit.operating_company&.name,
                            unit.name].compact.join(' / '), company_id: unit.company_id,
        issuer: JrcCrm::CorporateIssuer.attributes(unit),
        proposal_defaults: JrcCrm::ProposalProfile.defaults(crm_scope, unit: unit)
      }
    end,
                   unit_required: !allowed_ids.nil?, proposal_defaults: JrcCrm::ProposalProfile.defaults(crm_scope) }
  end

  private

  def authorize_operating_unit!(unit)
    boundary = JrcCrm::OrganizationalVisibility.new(account: crm_scope, user: Current.user,
                                                    relation: JrcCrm::Proposal.where(account_id: crm_scope.id), include_company: false)
    return if boundary.allowed_business_unit_ids.nil?
    raise Pundit::NotAuthorizedError unless unit && boundary.allowed_business_unit_ids.include?(unit.id)
  end

  def corporate_proposal_attributes
    attributes = proposal_params.to_h.symbolize_keys
    references = attributes.slice(:business_unit_id, :company_id, :contact_id)
    changed = references.any? { |key, value| value.to_s != @proposal.public_send(key).to_s }
    if changed
      unless @proposal.draft? && @proposal.sent_at.nil? && !@proposal.sales_orders.exists?
        raise JrcCrm::CommercialFinancials::InvalidTerms, 'Crie uma nova versão antes de alterar empresa ou contato de um documento enviado.'
      end
      if attributes.key?(:company_id) || attributes.key?(:contact_id)
        authorize :directory, :access?, policy_class: JrcCustomers::DirectoryPolicy
        attributes[:company_id] = corporate_records(:master_companies).find(attributes[:company_id]).id if attributes[:company_id].present?
        attributes[:contact_id] = corporate_records(:contacts).find(attributes[:contact_id]).id if attributes[:contact_id].present?
      end
    end
    unit_changed = attributes.key?(:business_unit_id) && attributes[:business_unit_id].to_s != @proposal.business_unit_id.to_s
    unit = @proposal.business_unit
    unit = attributes[:business_unit_id].present? ? crm_scope.jrc_crm_business_units.active.find(attributes[:business_unit_id]) : nil if unit_changed
    if unit_changed
      authorize_operating_unit!(unit)
      JrcCrm::CorporateIssuer.authorize!(account: crm_scope, user: Current.user, unit: unit)
      if JrcCrm::ProposalProfile.gopure?(crm_scope, unit: unit) != JrcCrm::ProposalProfile.gopure?(crm_scope, unit: @proposal.business_unit)
        raise JrcCrm::CommercialFinancials::InvalidTerms, 'Crie uma proposta separada para uma emissora com outro perfil comercial.'
      end
      if @proposal.deal && @proposal.deal.business_unit_id != unit&.id
        raise JrcCrm::CommercialFinancials::InvalidTerms, 'A emissora deve corresponder à unidade do negócio.'
      end
      @proposal.proposal_items.includes(:product).each do |item|
        if item.product&.business_unit_id && item.product.business_unit_id != unit&.id
          raise JrcCrm::CommercialFinancials::InvalidTerms, 'Os produtos devem pertencer à emissora selecionada.'
        end
      end
    end
    attributes.merge(JrcCrm::CorporateIssuer.attributes(unit))
  end

  def build_corporate_proposal(deal, company, contact, unit, attributes)
    items = params.permit(items: [:product_id, :quantity, :unit_price_cents, :discount_cents,
                                  { commercial_gratuity: [:type, :reason] }])[:items] || []
    JrcCrm::ProposalBuilderService.new(deal: deal, account: crm_scope, company: company, contact: contact,
                                       business_unit: unit, attributes: attributes, items: items, actor: Current.user).call
  end
end
