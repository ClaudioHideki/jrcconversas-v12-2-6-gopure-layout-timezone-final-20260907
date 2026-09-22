module Api
  module V1
    module Accounts
      module Crm
        class StagesController < BaseController
          before_action :set_stage, only: [:show, :update, :destroy]

          def index
            stages = crm_scope.jrc_crm_stages.where(pipeline_id: params[:pipeline_id]).order(:position)
            render json: stages.map { |stage| JrcCrm::StageSerializer.new(stage).as_json }
          end

          def show
            render json: JrcCrm::StageSerializer.new(@stage).as_json
          end

          def create
            ensure_crm_admin!
            stage = crm_scope.jrc_crm_stages.new(stage_params)
            
            if stage.save
              render json: JrcCrm::StageSerializer.new(stage).as_json, status: :created
            else
              render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            ensure_crm_admin!
            if @stage.update(stage_params)
              render json: JrcCrm::StageSerializer.new(@stage).as_json
            else
              render json: { errors: @stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            ensure_crm_admin!
            if @stage.destroy
              head :no_content
            else
              render json: { errors: @stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def reorder
            ensure_crm_admin!
            entries = params.require(:stages)
            ids = entries.map { |row| row[:id].to_i }
            positions = entries.map { |row| row[:position].to_i }
            raise ArgumentError, 'Informe etapas e posições únicas.' if ids.empty? || ids.uniq.length != ids.length || positions.uniq.length != positions.length

            stages = ids.map { |id| crm_scope.jrc_crm_stages.find(id) }
            raise ArgumentError, 'Ordene apenas etapas do mesmo funil.' unless stages.map(&:pipeline_id).uniq.one?

            ActiveRecord::Base.transaction do
              stages.zip(positions).each { |stage, position| stage.update!(position: position) }
            end
            render json: { message: 'Stages reordered successfully' }
          rescue ActiveRecord::RecordInvalid, ArgumentError => e
            render json: { errors: [e.message] }, status: :unprocessable_entity
          end

          private

          def set_stage
            @stage = crm_scope.jrc_crm_stages.find(params[:id])
          end

          def stage_params
            params.require(:stage).permit(:name, :key, :position, :color, :probability, :is_terminal, :is_won, :is_lost, :active, :pipeline_id)
          end
        end
      end
    end
  end
end
