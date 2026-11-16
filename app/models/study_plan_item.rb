class StudyPlanItem < ApplicationRecord
  belongs_to :study_plan

  MAX_TOPIC = 150
  MAX_ACTIVITY = 500
  validates :week, numericality: { greater_than: 0 }, presence: true, on: :input
  validates :day, inclusion: { in: StudyPlan::WEEKDAYS }, presence: true, on: :input
  validates :duration_minutes, numericality: { greater_than: 0, only_integer: true }, presence: true, on: :input
  validates :topic, length: { maximum: MAX_TOPIC }, presence: true, on: :input
  validates :activity, length: { maximum: MAX_ACTIVITY }, presence: true, on: :input

  validate :compatible_day
  validate :duration_must_be_integer, on: :input

  def compatible_day
    return if study_plan.available_days&.include?(day)

    errors.add(:day, "Os dias gerados devem ser compatíveis com os dias disponíveis")
  end

  def duration_must_be_integer
    raw_duration = duration_minutes_before_type_cast
    return if raw_duration.blank? || raw_duration.is_a?(Integer)

    errors.add(:duration_minutes, "deve ser um número inteiro")
  end
end
