class StudyPlansController < ApplicationController
  def new
    @study_plan = StudyPlan.new
  end

  def create
    @study_plan = StudyPlan.new(study_plan_params)

    if @study_plan.valid?(:input)
      render :new
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @study_plan = StudyPlan.find(params[:id])
  end

  private

  def study_plan_params
    params.require(:study_plan).permit(
      :objective,
      :current_level,
      :deadline,
      :daily_hours,
      :goal,
      available_days: []
    ).compact_blank
  end
end