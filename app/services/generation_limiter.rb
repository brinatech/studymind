class GenerationLimiter
  class LimitExceeded < StandardError
  end

  WINDOW = 1.day

  def initialize(ip:, limit:)
    @ip = ip
    @limit = limit.to_i
  end

  def check!
    count = Rails.cache.increment(cache_key, 1, expires_in: WINDOW)
    if count.nil?
      Rails.cache.write(cache_key, 1, expires_in: WINDOW)
      count = 1
    end

    raise LimitExceeded if count > @limit

    count
  end

  private

  def cache_key
    "generation:#{@ip}:#{Date.current}"
  end
end
