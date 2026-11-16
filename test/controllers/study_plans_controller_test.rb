require "test_helper"

class StudyPlansControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "generates, saves and redirects to the study plan" do
    result = {
      title: "Plano de SQL",
      items: [
        {
          week: 1,
          day: "Segunda-feira",
          topic: "SELECT",
          duration_minutes: 60,
          activity: "Praticar consultas"
        }
      ]
    }
    plans_before = StudyPlan.count

    with_generator_result(result) do
      post study_plans_path, params: valid_params
    end

    assert_response :see_other
    assert_redirected_to study_plan_path(StudyPlan.order(:id).last)
    assert_equal "Plano gerado com sucesso!", flash[:notice]
    assert_equal plans_before + 1, StudyPlan.count
    assert_equal 1, StudyPlan.order(:id).last.study_plan_items.count
  end

  test "does not persist when the generator rejects the response" do
    plans_before = StudyPlan.count

    with_generator_error(AI::Errors::InvalidResponseError.new("weeks[0] inválida")) do
      post study_plans_path, params: valid_params
    end

    assert_response :unprocessable_entity
    assert_equal plans_before, StudyPlan.count
    assert_equal "Não foi possível gerar o plano agora. Tente novamente.", flash[:alert]
  end

  private

  def valid_params
    {
      study_plan: {
        objective: "aprender SQL",
        current_level: "Iniciante",
        deadline: (Date.current + 7.days).to_s,
        daily_hours: "1",
        available_days: [ "Segunda-feira" ],
        goal: "escrever consultas"
      }
    }
  end

  def with_generator_result(result)
    original = AI::StudyPlanGenerator.method(:call)
    AI::StudyPlanGenerator.define_singleton_method(:call) { |*_args, **_kwargs| result }
    yield
  ensure
    AI::StudyPlanGenerator.define_singleton_method(:call) do |*args, **kwargs|
      original.call(*args, **kwargs)
    end
  end

  def with_generator_error(error)
    original = AI::StudyPlanGenerator.method(:call)
    AI::StudyPlanGenerator.define_singleton_method(:call) { |*_args, **_kwargs| raise error }
    yield
  ensure
    AI::StudyPlanGenerator.define_singleton_method(:call) do |*args, **kwargs|
      original.call(*args, **kwargs)
    end
  end
end
