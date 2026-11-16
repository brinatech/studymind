require "test_helper"

class StudyPlanTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "is valid in the input context" do
    assert build_study_plan.valid?(:input)
  end

  test "requires every input field" do
    [ :objective, :current_level, :deadline, :daily_hours, :available_days, :goal ].each do |field|
      study_plan = build_study_plan
      study_plan.public_send("#{field}=", field == :available_days ? [] : nil)

      refute study_plan.valid?(:input), "expected #{field} to be invalid"
      assert study_plan.errors[field].any?, "expected an error on #{field}"
    end
  end

  test "enforces objective and goal length limits" do
    study_plan = build_study_plan
    study_plan.objective = "a" * (StudyPlan::MAX_OBJECTIVE_LENGTH + 1)
    study_plan.goal = "a" * (StudyPlan::MAX_GOAL_LENGTH + 1)

    refute study_plan.valid?(:input)
    assert study_plan.errors[:objective].any?
    assert study_plan.errors[:goal].any?
  end

  test "rejects invalid daily hours" do
    [ 0, -1, StudyPlan::MAX_DAILY_HOURS + 1 ].each do |hours|
      study_plan = build_study_plan
      study_plan.daily_hours = hours

      refute study_plan.valid?(:input)
      assert study_plan.errors[:daily_hours].any?
    end
  end

  test "rejects empty and invalid available days" do
    empty_plan = build_study_plan
    empty_plan.available_days = []
    refute empty_plan.valid?(:input)

    invalid_plan = build_study_plan
    invalid_plan.available_days = [ "Feriado" ]
    refute invalid_plan.valid?(:input)
    assert invalid_plan.errors[:available_days].any?
  end

  test "rejects deadlines in the past and beyond the maximum" do
    past_plan = build_study_plan
    past_plan.deadline = Date.current
    refute past_plan.valid?(:input)

    distant_plan = build_study_plan
    distant_plan.deadline = Date.current + (StudyPlan::MAX_WEEKS + 1).weeks
    refute distant_plan.valid?(:input)
  end

  test "requires title and items in generation context" do
    study_plan = build_study_plan

    refute study_plan.valid?(:generation)
    assert study_plan.errors[:title].any?
    assert study_plan.errors[:study_plan_items].any?
  end

  test "calculates available weeks" do
    study_plan = build_study_plan
    study_plan.deadline = Date.current + 15.days

    assert_equal 3, study_plan.weeks_available
  end

  test "groups items by week and sorts them by weekday and id" do
    study_plan = build_study_plan(title: "Plano")
    early_item = study_plan.study_plan_items.build(week: 1, day: "Segunda-feira", duration_minutes: 30, topic: "SELECT", activity: "Exercitar")
    late_item = study_plan.study_plan_items.build(week: 1, day: "Quinta-feira", duration_minutes: 30, topic: "JOIN", activity: "Exercitar")
    other_week_item = study_plan.study_plan_items.build(week: 2, day: "Segunda-feira", duration_minutes: 30, topic: "WHERE", activity: "Exercitar")
    study_plan.save!(context: :generation)

    grouped = study_plan.reload.items_by_week

    assert_equal [ early_item, late_item ], grouped[1]
    assert_equal [ other_week_item ], grouped[2]
  end

  private

  def build_study_plan(attributes = {})
    StudyPlan.new({
      objective: "aprender SQL",
      current_level: "Iniciante",
      deadline: Date.current + 7.days,
      daily_hours: 1,
      available_days: [ "Segunda-feira", "Quinta-feira" ],
      goal: "escrever consultas"
    }.merge(attributes))
  end
end
