module Api
  module V1
    module Accounts
      module JrcCampaigns
        class BaseController < Api::V1::Accounts::BaseController
          before_action :ensure_jrc_campaigns_enabled!

          private

          def ensure_jrc_campaigns_enabled!
            return if Current.account.feature_enabled?('jrc_campaigns')

            render json: { error: 'JRC Campanhas não está habilitado para esta conta' }, status: :forbidden
          end
        end
      end
    end
  end
end
