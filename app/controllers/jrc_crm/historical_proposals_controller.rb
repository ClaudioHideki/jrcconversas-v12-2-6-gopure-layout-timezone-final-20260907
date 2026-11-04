class JrcCrm::HistoricalProposalsController < ApplicationController
  before_action :set_document

  def show
    render layout: false
  end

  def pdf
    send_data @document.download, type: 'application/pdf', filename: @document.filename.to_s,
                                  disposition: ActiveModel::Type::Boolean.new.cast(params[:download]) ? 'attachment' : 'inline'
  end

  private

  def set_document
    response.headers['Cache-Control'] = 'private, no-store'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow'
    data = JrcCrm::HistoricalProposalLink.verify(params[:token])
    raise ActiveRecord::RecordNotFound unless data && data['account_id'] == params[:account_id].to_i

    @proposal = JrcCrm::Proposal.find_by!(id: data['proposal_id'], account_id: data['account_id'])
    raise ActiveRecord::RecordNotFound unless @proposal.account.feature_enabled?('jrc_crm')

    @document = JrcCrm::ProposalDocumentArchive.new(@proposal).blob
    raise ActiveRecord::RecordNotFound unless @document
  end
end
