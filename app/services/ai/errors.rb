module AI
  module Errors
    class Base < StandardError
    end

    class ConfigurationError < Base
    end

    class RateLimitError < Base
    end

    class ApiError < Base
    end

    class InvalidResponseError < Base
    end
  end
end
