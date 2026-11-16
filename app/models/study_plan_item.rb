class StudyPlanItem < ApplicationRecord
belongs_to :study_plan
MAX_TOPIC = 150
MAX_ACTIVITY = 500
  validates :week, numericality: { greater_than: 0 }, presence: true, on: :input
  validates :day, inclusion: { in: StudyPlan::WEEKDAYS }, presence: true, on: :input
  validates :duration_minutes, numericality: { greater_than: 0 }, presence: true, on: :input
  validates :topic, length: { maximum: MAX_TOPIC }, presence: true, on: :input
  validates :activity, length: { maximum: MAX_ACTIVITY }, presence: true, on: :input

  validate :compatible_day

  def compatible_day
   return if study_plan.available_days&.include?(day)
     errors(:day, "Os dias gerados devem ser compatíveis com os dias disponíveis")
   end

end
