class StudyPlansController < ApplicationController
  GENERATION_ERROR_MESSAGES = {
    AI::Errors::ConfigurationError => "O serviço de geração está indisponível no momento. Tente novamente mais tarde.",
    AI::Errors::RateLimitError => "O serviço de IA está com muitas solicitações. Aguarde alguns minutos e tente de novo.",
    AI::Errors::ApiError => "Não foi possível gerar seu plano agora. Tente novamente em instantes.",
    AI::Errors::InvalidResponseError => "Não conseguimos gerar um plano válido desta vez. Tente novamente.",
    ActiveRecord::RecordInvalid => "Não conseguimos gerar um plano válido desta vez. Tente novamente."
  }.freeze

  def new
    @study_plan = StudyPlan.new
  end

  def create
    @study_plan = StudyPlan.new(study_plan_params)

    if @study_plan.valid?(:input)
      begin
        daily_limit = Rails.configuration.x.study_mind.daily_limit
        GenerationLimiter.new(ip: request.remote_ip, limit: daily_limit).check!

        result = AI::StudyPlanGenerator.call(@study_plan)
        @study_plan.title = result[:title]
        result[:items].each { |item| @study_plan.study_plan_items.build(item) }
        @study_plan.save!(context: :generation)

        redirect_to study_plan_path(@study_plan), status: :see_other, notice: "Plano gerado com sucesso!"
      rescue GenerationLimiter::LimitExceeded
        daily_limit = Rails.configuration.x.study_mind.daily_limit
        flash.now[:alert] = "Você atingiu o limite de #{daily_limit} planos por dia. Volte amanhã."
        render :new, status: :too_many_requests
      rescue AI::Errors::Base, ActiveRecord::RecordInvalid => error
        handle_generation_error(error)
      rescue StandardError => error
        handle_generation_error(error)
      end
    else
      render :new, status: :unprocessable_entity
    end
  end


  def show
    @study_plan = StudyPlan.includes(:study_plan_items).find(params[:id])
  end

  private

  def handle_generation_error(error)
    backtrace = Array(error.backtrace).first(10).join("\n")
    Rails.logger.error("Study plan generation failed error=#{error.class.name} message=#{safe_error_message(error)}\n#{backtrace}")
    flash.now[:alert] = GENERATION_ERROR_MESSAGES.fetch(error.class, GENERATION_ERROR_MESSAGES[AI::Errors::ApiError])
    render :new, status: :service_unavailable
  end

  def safe_error_message(error)
    message = error.message.to_s
    api_key = Rails.configuration.x.gemini.api_key.to_s
    api_key.empty? ? message : message.gsub(api_key, "[REDACTED]")
  end

  def study_plan_params
  permitted = params.require(:study_plan).permit(
    :objective,
    :current_level,
    :deadline,
    :daily_hours,
    :goal,
    available_days: []
  )

  permitted[:available_days] = permitted[:available_days].compact_blank

  permitted
end
end
