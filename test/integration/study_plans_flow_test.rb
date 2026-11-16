require "test_helper"

class StudyPlansFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  GEMINI_URL = %r{https://generativelanguage\.googleapis\.com/v1beta/models/.+:generateContent}
  API_KEY = "integration-test-key"

  setup do
    Rails.cache.clear
    @previous_api_key = Rails.configuration.x.gemini.api_key
    @previous_model = Rails.configuration.x.gemini.model
    @previous_limit = Rails.configuration.x.study_mind.daily_limit
    Rails.configuration.x.gemini.api_key = API_KEY
    Rails.configuration.x.gemini.model = "gemini-2.5-flash"
    Rails.configuration.x.study_mind.daily_limit = 5
  end

  teardown do
    Rails.configuration.x.gemini.api_key = @previous_api_key
    Rails.configuration.x.gemini.model = @previous_model
    Rails.configuration.x.study_mind.daily_limit = @previous_limit
  end

  test "GET new renders the study plan form" do
    get new_study_plan_path

    assert_response :success
    assert_select "form"
    assert_select "textarea[name='study_plan[objective]']"
  end

  test "invalid input is rejected without calling Gemini or persisting" do
    plans_before = StudyPlan.count

    post study_plans_path, params: {
      study_plan: {
        objective: "",
        current_level: "",
        deadline: "",
        daily_hours: "",
        available_days: [ "" ],
        goal: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".field-msg"
    assert_equal plans_before, StudyPlan.count
    assert_not_requested :post, GEMINI_URL
  end

  test "valid Gemini response creates a plan and redirects to show" do
    stub_gemini(file_body("gemini_valid_response.json"))
    plans_before = StudyPlan.count

    post study_plans_path, params: valid_params

    plan = StudyPlan.order(:id).last
    assert_response :see_other
    assert_redirected_to study_plan_path(plan)
    assert_equal plans_before + 1, StudyPlan.count
    assert_equal 1, plan.study_plan_items.count

    follow_redirect!
    assert_select "h1", "Plano de SQL"
    assert_select "h3", "SELECT"
  end

  test "Gemini HTTP failure returns a safe error without persisting" do
    stub_gemini('{"error":{"message":"provider internals"}}', status: 500)
    plans_before = StudyPlan.count

    post study_plans_path, params: valid_params

    assert_response :service_unavailable
    assert_includes response.body, "Não foi possível gerar seu plano agora"
    refute_includes response.body, "provider internals"
    assert_equal plans_before, StudyPlan.count
  end

  test "invalid Gemini response returns a safe error without persisting" do
    stub_gemini(file_body("gemini_malformed_response.json"))
    plans_before = StudyPlan.count

    post study_plans_path, params: valid_params

    assert_response :service_unavailable
    assert_includes response.body, "Não conseguimos gerar um plano válido"
    refute_includes response.body, "not-json"
    assert_equal plans_before, StudyPlan.count
  end

  test "the usage limit returns 429 before the second Gemini request" do
    Rails.configuration.x.study_mind.daily_limit = 1
    stub_gemini(file_body("gemini_valid_response.json"))

    post study_plans_path, params: valid_params
    post study_plans_path, params: valid_params

    assert_response :too_many_requests
    assert_includes response.body, "Você atingiu o limite de 1 planos por dia"
    assert_requested :post, GEMINI_URL, times: 1
  end

  test "a missing plan renders the friendly 404 page" do
    get "/study_plans/0"

    assert_response :not_found
    assert_includes response.body, "Essa página não foi encontrada."
    assert_includes response.body, "Voltar para o StudyMind"
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

  def stub_gemini(body, status: 200)
    stub_request(:post, GEMINI_URL)
      .with(headers: { "x-goog-api-key" => API_KEY })
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  def file_body(name)
    Rails.root.join("test/fixtures/files", name).read
  end
end
