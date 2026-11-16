require "test_helper"

class AI::StudyPlanResponseValidatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "rejects a response without the required root structure" do
    assert_invalid({})
    assert_invalid({ "title" => "Plano", "weeks" => [] })
    assert_invalid({ "title" => "Plano", "weeks" => [ {} ] })
  end

  test "rejects invalid duration values" do
    [ 0, -1, 1.5, "30" ].each do |duration|
      response = valid_response.deep_dup
      response["weeks"][0]["topics"][0]["duration_minutes"] = duration

      assert_invalid(response)
    end
  end

  test "rejects days unavailable to the study plan" do
    response = valid_response
    response["weeks"][0]["topics"][0]["day"] = "Quinta-feira"

    error = assert_invalid(response)

    assert_includes error.message, "day is not available"
  end

  test "rejects weeks outside the available range" do
    response = valid_response
    response["weeks"][0]["week"] = 2

    assert_invalid(response)
  end

  test "rejects oversized title, topic and activity" do
    response = valid_response
    response["title"] = "a" * (StudyPlan::MAX_TITLE_LENGTH + 1)
    assert_invalid(response)

    response = valid_response
    response["weeks"][0]["topics"][0]["topic"] = "a" * (StudyPlanItem::MAX_TOPIC + 1)
    assert_invalid(response)

    response = valid_response
    response["weeks"][0]["topics"][0]["activity"] = "a" * (StudyPlanItem::MAX_ACTIVITY + 1)
    assert_invalid(response)
  end

  test "rejects a response with too many items or no items" do
    response = valid_response
    response["weeks"][0]["topics"] = Array.new(StudyPlan::MAX_ITEMS + 1) { response["weeks"][0]["topics"].first.dup }
    assert_invalid(response)

    empty_response = { "title" => "Plano", "weeks" => [ { "week" => 1, "topics" => [] } ] }
    assert_invalid(empty_response)
  end

  private

  def valid_response
    {
      "title" => "Plano",
      "weeks" => [
        {
          "week" => 1,
          "topics" => [
            {
              "day" => "Segunda-feira",
              "topic" => "SELECT",
              "duration_minutes" => 60,
              "activity" => "Praticar consultas"
            }
          ]
        }
      ]
    }
  end

  def study_plan
    StudyPlan.new(
      objective: "aprender SQL",
      current_level: "Iniciante",
      deadline: Date.current + 7.days,
      daily_hours: 1,
      available_days: [ "Segunda-feira" ],
      goal: "escrever consultas"
    )
  end

  def assert_invalid(response)
    assert_raises(AI::Errors::InvalidResponseError) do
      AI::StudyPlanResponseValidator.validate!(response, study_plan)
    end
  end
end
