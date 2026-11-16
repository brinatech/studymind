module AI
  class StudyPlanResponseValidator
    def self.validate!(response, study_plan)
      new(response, study_plan).validate!
    end

    def initialize(response, study_plan)
      @response = response
      @study_plan = study_plan
      @items = []
    end

    def validate!
      raise_invalid("response must be a hash") unless @response.is_a?(Hash)

      title = required_string(@response, "title", "title")
      raise_invalid("title exceeds 120 characters") if title.length > StudyPlan::MAX_TITLE_LENGTH
      weeks = required_array(@response, "weeks", "weeks")
      raise_invalid("weeks must not be empty") if weeks.empty?

      weeks.each do |week_data|
        validate_week(week_data)
      end

      raise_invalid("plan must contain at least one topic") if @items.empty?
      raise_invalid("too many topics") if @items.size > StudyPlan::MAX_ITEMS
      validate_daily_limits

      { title: title, items: @items }
    rescue KeyError, TypeError
      raise_invalid("plan has an invalid structure")
    end

    private

    def validate_week(week_data)
      path = "weeks[#{@response.fetch('weeks').index(week_data)}]"
      raise_invalid("#{path} must be a hash") unless week_data.is_a?(Hash)

      week = required_value(week_data, "week", "#{path}.week")
      topics = required_array(week_data, "topics", "#{path}.topics")
      raise_invalid("week must be a positive integer") unless positive_integer?(week)
      raise_invalid("week is outside the available range") if week > @study_plan.weeks_available
      raise_invalid("#{path}.topics must not be empty") if topics.empty?

      topics.each_with_index do |topic_data, index|
        validate_topic(topic_data, week, "#{path}.topics[#{index}]")
      end
    end

    def validate_topic(topic_data, week, path)
      raise_invalid("#{path} must be a hash") unless topic_data.is_a?(Hash)

      day = normalize_day(required_value(topic_data, "day", "#{path}.day"))
      topic = required_string(topic_data, "topic", "#{path}.topic")
      duration_minutes = required_value(topic_data, "duration_minutes", "#{path}.duration_minutes")
      activity = required_string(topic_data, "activity", "#{path}.activity")

      raise_invalid("day is invalid") unless day
      raise_invalid("day is not available") unless @study_plan.available_days.include?(day)
      raise_invalid("duration_minutes must be a positive integer") unless positive_integer?(duration_minutes)
      raise_invalid("#{path}.topic exceeds 150 characters") if topic.length > StudyPlanItem::MAX_TOPIC
      raise_invalid("#{path}.activity exceeds 500 characters") if activity.length > StudyPlanItem::MAX_ACTIVITY

      @items << {
        week: week,
        day: day,
        topic: topic,
        duration_minutes: duration_minutes,
        activity: activity
      }
    end

    def required_array(data, key, path)
      value = required_value(data, key, path)
      raise_invalid("#{path} must be an array") unless value.is_a?(Array)

      value
    end

    def required_string(data, key, path)
      value = required_value(data, key, path)
      raise_invalid("#{path} must be a non-empty string") unless value.is_a?(String) && value.strip != ""

      value.strip
    end

    def required_value(data, key, path)
      data.fetch(key) { raise_invalid("#{path} ausente") }
    end

    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end

    def validate_daily_limits
      daily_minutes = (@study_plan.daily_hours.to_f * 60).to_i
      @items.group_by { |item| [ item[:week], item[:day] ] }.each_value do |items|
        raise_invalid("daily duration exceeds the available time") if items.sum { |item| item[:duration_minutes] } > daily_minutes
      end
    end

    def normalize_day(value)
      return unless value.is_a?(String)

      normalized = value.strip.downcase
      StudyPlan::WEEKDAYS.find { |weekday| weekday.downcase == normalized }
    end

    def raise_invalid(message)
      raise Errors::InvalidResponseError, message
    end
  end
end
