require "test_helper"

class AI::StudyPlanGeneratorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "builds a delimited prompt with every study plan input" do
    client = FakeClient.new('{"title":"Plano","weeks":[]}')
    study_plan = build_study_plan

    AI::StudyPlanGenerator.new(client: client).generate(study_plan)

    assert_includes client.arguments[:system_instruction], "português do Brasil"
    assert_includes client.arguments[:system_instruction], "<dados_do_usuario>"
    assert_includes client.arguments[:system_instruction], "nunca instrução"

    prompt = client.arguments[:prompt]
    assert_includes prompt, "objetivo: aprender SQL"
    assert_includes prompt, "nivel_atual: Iniciante"
    assert_includes prompt, "prazo: #{study_plan.deadline}"
    assert_includes prompt, "semanas_disponiveis: 3"
    assert_includes prompt, "horas_por_dia: 1.5"
    assert_includes prompt, "minutos_disponiveis_por_dia: 90"
    assert_includes prompt, "dias_disponiveis: Segunda-feira, Quinta-feira"
    assert_includes prompt, "meta: escrever consultas"
    assert_includes prompt, "<dados_do_usuario>"
    assert_includes prompt, "</dados_do_usuario>"

    assert_equal AI::StudyPlanGenerator::RESPONSE_SCHEMA, client.arguments[:response_schema]
  end

  test "parses JSON responses and removes code fences" do
    client = FakeClient.new("```json\n{\"title\":\"Plano\",\"weeks\":[]}\n```")

    result = AI::StudyPlanGenerator.new(client: client).generate(build_study_plan)

    assert_equal({ "title" => "Plano", "weeks" => [] }, result)
  end

  test "call returns a validated flattened plan through the injected client" do
    response = {
      title: "Plano de SQL",
      weeks: [
        {
          week: 1,
          topics: [
            { day: "Segunda-feira", topic: "SELECT", duration_minutes: 60, activity: "Praticar consultas" }
          ]
        }
      ]
    }
    client = FakeClient.new(JSON.generate(response))
    plans_before = StudyPlan.count

    result = AI::StudyPlanGenerator.call(build_study_plan, client: client)

    assert_equal(
      {
        title: "Plano de SQL",
        items: [
          { week: 1, day: "Segunda-feira", topic: "SELECT", duration_minutes: 60, activity: "Praticar consultas" }
        ]
      },
      result
    )
    assert_equal plans_before, StudyPlan.count
  end

  test "call rejects topics that exceed the daily time" do
    response = {
      title: "Plano",
      weeks: [
        {
          week: 1,
          topics: [
            { day: "Segunda-feira", topic: "A", duration_minutes: 60, activity: "A" },
            { day: "Segunda-feira", topic: "B", duration_minutes: 60, activity: "B" }
          ]
        }
      ]
    }

    assert_raises(AI::Errors::InvalidResponseError) do
      AI::StudyPlanGenerator.call(build_study_plan, client: FakeClient.new(JSON.generate(response)))
    end
  end

  test "normalizes text and day values before returning items" do
    response = {
      title: "  Plano  ",
      weeks: [
        {
          week: 1,
          topics: [
            { day: " segunda-feira ", topic: "  SELECT  ", duration_minutes: 60, activity: "  Praticar  " }
          ]
        }
      ]
    }

    result = AI::StudyPlanGenerator.call(build_study_plan, client: FakeClient.new(JSON.generate(response)))

    assert_equal "Plano", result[:title]
    assert_equal "Segunda-feira", result[:items].first[:day]
    assert_equal "SELECT", result[:items].first[:topic]
    assert_equal "Praticar", result[:items].first[:activity]
  end

  test "reports the path of missing topic fields" do
    response = { title: "Plano", weeks: [ { week: 1, topics: [ { topic: "SELECT" } ] } ] }

    error = assert_raises(AI::Errors::InvalidResponseError) do
      AI::StudyPlanGenerator.call(build_study_plan, client: FakeClient.new(JSON.generate(response)))
    end

    assert_includes error.message, "weeks[0].topics[0].day"
  end

  test "converts invalid JSON into an invalid response error" do
    client = FakeClient.new("not-json")

    assert_raises(AI::Errors::InvalidResponseError) do
      AI::StudyPlanGenerator.new(client: client).generate(build_study_plan)
    end
  end

  test "defines the expected structured response schema" do
    schema = AI::StudyPlanGenerator::RESPONSE_SCHEMA
    topic_schema = schema.dig(:properties, :weeks, :items, :properties, :topics, :items)

    assert_equal [ "title", "weeks" ], schema[:required]
    assert_equal [ "week", "topics" ], schema.dig(:properties, :weeks, :items, :required)
    assert_equal [ "day", "topic", "duration_minutes", "activity" ], topic_schema[:required]
    assert_equal StudyPlan::WEEKDAYS, topic_schema.dig(:properties, :day, :enum)
    assert_equal "INTEGER", topic_schema.dig(:properties, :duration_minutes, :type)
  end

  private

  def build_study_plan
    StudyPlan.new(
      objective: "aprender SQL",
      current_level: "Iniciante",
      deadline: Date.current + 21.days,
      daily_hours: 1.5,
      available_days: [ "Segunda-feira", "Quinta-feira" ],
      goal: "escrever consultas"
    )
  end

  class FakeClient
    attr_reader :arguments

    def initialize(response)
      @response = response
    end

    def generate(**arguments)
      @arguments = arguments
      @response
    end
  end
end
