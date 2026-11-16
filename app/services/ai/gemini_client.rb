require "json"
require "net/http"
require "uri"

module AI
  class GeminiClient
    API_HOST = "generativelanguage.googleapis.com"
    API_PATH = "/v1beta/models"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    TEMPERATURE = 0.4
    MAX_OUTPUT_TOKENS = 8192
    LOG_BODY_LIMIT = 200

    def initialize(api_key: ENV["GEMINI_API_KEY"], model:)
      if api_key.nil? || api_key.to_s.strip.empty?
        raise Errors::ConfigurationError, "Gemini API key is missing"
      end

      @api_key = api_key
      @model = model
    end

    def generate(system_instruction:, prompt:, response_schema:)
      uri = endpoint_uri
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["x-goog-api-key"] = @api_key
      request.body = JSON.generate(request_body(system_instruction, prompt, response_schema))

      response = perform_request(uri, request)
      handle_http_response(response)
      extract_text(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Errors::ApiError, "Gemini request failed: #{e.class}"
    end

    private

    def endpoint_uri
      escaped_model = URI::DEFAULT_PARSER.escape(@model.to_s)
      URI("https://#{API_HOST}#{API_PATH}/#{escaped_model}:generateContent")
    end

    def request_body(system_instruction, prompt, response_schema)
      {
        systemInstruction: {
          parts: [ { text: system_instruction } ]
        },
        contents: [
          {
            role: "user",
            parts: [ { text: prompt } ]
          }
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: response_schema,
          temperature: TEMPERATURE,
          maxOutputTokens: MAX_OUTPUT_TOKENS
        }
      }
    end

    def perform_request(uri, request)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }
    end

    def handle_http_response(response)
      return if response.is_a?(Net::HTTPSuccess)

      log_http_failure(response)

      case response.code.to_i
      when 401, 403
        raise Errors::ConfigurationError, "Gemini API rejected the configuration"
      when 429
        raise Errors::RateLimitError, "Gemini API rate limit exceeded"
      else
        raise Errors::ApiError, "Gemini API returned HTTP #{response.code}"
      end
    end

    def log_http_failure(response)
      Rails.logger.warn(
        "Gemini API request failed status=#{response.code} body=#{response.body.to_s.first(LOG_BODY_LIMIT).inspect}"
      )
    end

    def extract_text(body)
      payload = JSON.parse(body)

      if payload.dig("promptFeedback", "blockReason")
        raise Errors::InvalidResponseError, "Gemini response was blocked"
      end

      candidate = payload.fetch("candidates").first
      finish_reason = candidate["finishReason"]
      if finish_reason && finish_reason != "STOP"
        raise Errors::InvalidResponseError, "Gemini response finished with #{finish_reason}"
      end

      text = candidate.dig("content", "parts", 0, "text")
      return text if text.is_a?(String) && !text.empty?

      raise Errors::InvalidResponseError, "Gemini response did not contain text"
    rescue JSON::ParserError, KeyError, NoMethodError, TypeError
      raise Errors::InvalidResponseError, "Gemini response has an invalid format"
    end
  end
end
