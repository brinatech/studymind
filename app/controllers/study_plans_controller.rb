class StudyPlansController < ApplicationController
  def new
    @study_plan = StudyPlan.new
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