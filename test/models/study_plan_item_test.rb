require "test_helper"

class StudyPlanItemTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "is valid in the input context" do
    assert build_item.valid?(:input)
  end

  test "rejects non-positive and non-integer durations" do
    [ 0, -1, 1.5, "30" ].each do |duration|
      item = build_item(duration_minutes: duration)

      refute item.valid?(:input)
      assert item.errors[:duration_minutes].any?
    end
  end

  test "rejects a zero week" do
    item = build_item(week: 0)

    refute item.valid?(:input)
    assert item.errors[:week].any?
  end

  test "rejects days outside the weekday list and availability" do
    invalid_day = build_item(day: "Feriado")
    refute invalid_day.valid?(:input)
    assert invalid_day.errors[:day].any?

    unavailable_day = build_item(day: "Quinta-feira", study_plan: build_study_plan(available_days: [ "Segunda-feira" ]))
    refute unavailable_day.valid?(:input)
    assert unavailable_day.errors[:day].any?
  end

  test "requires topic and activity" do
    item = build_item(topic: nil, activity: nil)

    refute item.valid?(:input)
    assert item.errors[:topic].any?
    assert item.errors[:activity].any?
  end

  test "destroys items when the study plan is destroyed" do
    study_plan = build_study_plan
    study_plan.study_plan_items.build(week: 1, day: "Segunda-feira", duration_minutes: 30, topic: "SELECT", activity: "Exercitar")
    study_plan.save!(context: :generation)
    item = study_plan.study_plan_items.first

    assert_difference("StudyPlanItem.count", -1) { study_plan.destroy! }
    refute StudyPlanItem.exists?(item.id)
  end

  private

  def build_study_plan(attributes = {})
    StudyPlan.new({
      title: "Plano",
      objective: "aprender SQL",
      current_level: "Iniciante",
      deadline: Date.current + 7.days,
      daily_hours: 1,
      available_days: [ "Segunda-feira" ],
      goal: "escrever consultas"
    }.merge(attributes))
  end

  def build_item(attributes = {})
    study_plan = attributes.delete(:study_plan) { build_study_plan }
    StudyPlanItem.new({
      study_plan: study_plan,
      week: 1,
      day: "Segunda-feira",
      duration_minutes: 30,
      topic: "SELECT",
      activity: "Exercitar"
    }.merge(attributes))
  end
end
