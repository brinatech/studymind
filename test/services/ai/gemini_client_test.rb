require "test_helper"
require "stringio"

class AI::GeminiClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  MODEL = "gemini-2.5-flash"
  API_KEY = "test-gemini-key"
  SCHEMA = { type: "OBJECT", properties: { answer: { type: "STRING" } } }

  test "sends the structured request and returns generated text" do
    response = http_response(200, {
      candidates: [
        {
          content: { parts: [ { text: '{"answer":"ok"}' } ] },
          finishReason: "STOP"
        }
      ]
    })
    request = nil

    with_http_response(response) do |fake_http|
      result = client.generate(
        system_instruction: "Return JSON only",
        prompt: "Answer this",
        response_schema: SCHEMA
      )
      request = fake_http.requested_request
      assert_equal '{"answer":"ok"}', result
    end

    assert_equal "application/json", request["Content-Type"]
    assert_equal API_KEY, request["x-goog-api-key"]
    assert_equal "/v1beta/models/#{MODEL}:generateContent", request.path
    refute_includes request.path, API_KEY

    body = JSON.parse(request.body)
    assert_equal({ "parts" => [ { "text" => "Return JSON only" } ] }, body["systemInstruction"])
    assert_equal({ "role" => "user", "parts" => [ { "text" => "Answer this" } ] }, body["contents"].first)
    assert_equal "application/json", body.dig("generationConfig", "responseMimeType")
    assert_equal JSON.parse(JSON.generate(SCHEMA)), body.dig("generationConfig", "responseSchema")
    assert_equal 0.4, body.dig("generationConfig", "temperature")
    assert_equal 8192, body.dig("generationConfig", "maxOutputTokens")
  end

  test "uses the configured HTTP timeouts" do
    response = http_response(200, valid_payload)
    options = nil

    stub_http_start(lambda { |*args, &block|
      options = args
      block.call(FakeHttp.new(response))
    }) do
      client.generate(system_instruction: "system", prompt: "prompt", response_schema: SCHEMA)
    end

    assert_equal(
      { use_ssl: true, open_timeout: 5, read_timeout: 30 },
      options.last
    )
  end

  test "raises configuration error when the API key is missing" do
    error = assert_raises(AI::Errors::ConfigurationError) do
      AI::GeminiClient.new(api_key: "  ", model: MODEL)
    end

    assert_match(/api key/i, error.message)
  end

  test "maps authentication failures to configuration error" do
    assert_status_error(401, AI::Errors::ConfigurationError)
    assert_status_error(403, AI::Errors::ConfigurationError)
  end

  test "maps rate limiting to rate limit error" do
    assert_status_error(429, AI::Errors::RateLimitError)
  end

  test "maps other HTTP failures to API error" do
    assert_status_error(400, AI::Errors::ApiError)
    assert_status_error(500, AI::Errors::ApiError)
  end

  test "maps network failures to API error" do
    [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED ].each do |error_class|
      stub_http_start(->(*) { raise error_class, "failure" }) do
        assert_raises(AI::Errors::ApiError) do
          client.generate(system_instruction: "system", prompt: "prompt", response_schema: SCHEMA)
        end
      end
    end
  end

  test "rejects blocked, unfinished, malformed and empty responses" do
    blocked = { promptFeedback: { blockReason: "SAFETY" } }
    unfinished = { candidates: [ { content: { parts: [ { text: "partial" } ] }, finishReason: "MAX_TOKENS" } ] }
    malformed = "not-json"
    empty = { candidates: [ { content: { parts: [] }, finishReason: "STOP" } ] }

    [ blocked, unfinished, malformed, empty ].each do |payload|
      with_http_response(http_response(200, payload)) do
        assert_raises(AI::Errors::InvalidResponseError) do
          client.generate(system_instruction: "system", prompt: "prompt", response_schema: SCHEMA)
        end
      end
    end
  end

  private

  def client
    AI::GeminiClient.new(api_key: API_KEY, model: MODEL)
  end

  def valid_payload
    {
      candidates: [
        {
          content: { parts: [ { text: "generated" } ] },
          finishReason: "STOP"
        }
      ]
    }
  end

  def http_response(status, payload)
    response_class = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s)
    response = response_class.new("1.1", status.to_s, "status")
    body = payload.is_a?(String) ? payload : JSON.generate(payload)
    response.define_singleton_method(:body) { body }
    response
  end

  def with_http_response(response)
    fake_http = FakeHttp.new(response)
    stub_http_start(lambda { |*args, &block|
      block.call(fake_http)
    }) do
      yield fake_http
    end
  end

  def assert_status_error(status, error_class)
    with_http_response(http_response(status, { error: { message: "failure" } })) do
      assert_raises(error_class) do
        client.generate(system_instruction: "system", prompt: "prompt", response_schema: SCHEMA)
      end
    end
  end

  def stub_http_start(handler)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &handler)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start) do |*args, &block|
      original.call(*args, &block)
    end
  end

  class FakeHttp
    attr_reader :requested_request

    def initialize(response)
      @response = response
    end

    def request(request)
      @requested_request = request
      @response
    end
  end
end
