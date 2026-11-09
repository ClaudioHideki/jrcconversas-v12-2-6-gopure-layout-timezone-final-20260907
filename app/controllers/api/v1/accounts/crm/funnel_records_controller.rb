class Api::V1::Accounts::Crm::FunnelRecordsController < Api::V1::Accounts::Crm::BaseController
  def index
    start_date, end_date = commercial_metric_dates
    render json: JrcCrm::FunnelRecordsService.new(
      account: crm_scope, actor: Current.user, search: params[:search],
      filters: { owner_id: params[:owner_id], pipeline_id: params[:pipeline_id], start_date: start_date, end_date: end_date }
    ).call
  end
end
