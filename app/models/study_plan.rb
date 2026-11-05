class StudyPlan < ApplicationRecord
has_many :study_plan_items
  WEEKDAYS = [ "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo" ].freeze
  LEVELS = [ "Iniciante", "Intermediário", "Avançado" ].freeze
  MAX_OBJECTIVE_LENGTH = 300
  MAX_GOAL_LENGTH = 300
  MAX_TITLE_LENGTH = 120
  MAX_DAILY_HOURS = 12
  MAX_WEEKS = 12
  validates :objective, presence: true, on: :input
  validates :deadline, presence: true, on: :input
  validates :daily_hours, presence: true, on: :input
  validates :available_days, presence: true, on: :input
  validates :goal, presence: true, on: :input
  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :objective, length: { maximum: MAX_OBJECTIVE_LENGTH }, on: :input
  validates :goal, length: { maximum: MAX_GOAL_LENGTH }, on: :input
  validates :current_level, presence: true, inclusion: { in: LEVELS }, on: :input
  validates :daily_hours, numericality: { greater_than: 0, less_than_or_equal_to: MAX_DAILY_HOURS },
  on: :input
  validate :validate_available_days, on: :input
  validate :validate_deadline, on: :input
  validate :must_have_items
  normalizes :objective, :goal, with: ->(v) { v.strip }

  def validate_available_days
     if available_days.blank?
      errors.add(:available_days, "Deve conter pelo menos um dia")
      return
     end

invalid_days = available_days - WEEKDAYS

    if invalid_days.any?
     errors.add(:available_days, "Contém dias inválidos")
    end
  end

  def validate_deadline
  return if deadline.blank?

  if deadline <= Date.current
    errors.add(:deadline, "Deve ser posterior a hoje")
    return
  end

  deadline_total = Date.current + MAX_WEEKS.weeks

  if deadline > deadline_total
   errors.add(:deadline, "Não deve passar de 12 semanas")
  end
  end

  def must_have_items
    if study_plan_items.empty?
     errors.add(:study_plan_items, "Deve haver pelo menos um studyplanitem")
    end
  end

  def weeks_available
    ((deadline - Date.current)/7.0).ceil.clamp(0, MAX_WEEKS)
  end
end
