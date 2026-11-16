require "test_helper"

class GenerationLimiterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    Rails.cache.clear
  end

  test "allows generations up to the configured limit" do
    limiter = GenerationLimiter.new(ip: "203.0.113.10", limit: 2)

    assert_equal 1, limiter.check!
    assert_equal 2, limiter.check!
  end

  test "raises when the limit is exceeded for the same IP and day" do
    limiter = GenerationLimiter.new(ip: "203.0.113.10", limit: 1)
    limiter.check!

    assert_raises(GenerationLimiter::LimitExceeded) { limiter.check! }
  end

  test "uses a separate counter for each IP" do
    first_ip = GenerationLimiter.new(ip: "203.0.113.10", limit: 1)
    second_ip = GenerationLimiter.new(ip: "203.0.113.11", limit: 1)

    first_ip.check!
    assert_equal 1, second_ip.check!
  end
end
