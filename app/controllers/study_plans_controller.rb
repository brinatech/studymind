class StudyPlansController < ApplicationController
  def new
    @study_plan = StudyPlan.new
  end

  def create
    @study_plan = StudyPlan.new(study_plan_params)

    if @study_plan.valid?(:input)
      begin
        result = AI::StudyPlanGenerator.call(@study_plan)
        @study_plan.title = result[:title]
        result[:items].each { |item| @study_plan.study_plan_items.build(item) }
        @study_plan.save!(context: :generation)

        redirect_to study_plan_path(@study_plan), status: :see_other, notice: "Plano gerado com sucesso!"
      rescue AI::Errors::Base, ActiveRecord::RecordInvalid => error
        Rails.logger.warn("Study plan persistence failed result=#{error.class.name}")
        flash.now[:alert] = "Não foi possível gerar o plano agora. Tente novamente."
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end


  def show
    @study_plan = StudyPlan.includes(:study_plan_items).find(params[:id])
  end

  private

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
