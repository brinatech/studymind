module AI
  class StudyPlanResponseValidator
    def self.validate!(response, study_plan:)
      new(response, study_plan).validate!
    end

    def initialize(response, study_plan)
      @response = response
      @study_plan = study_plan
      @items = []
    end

    def validate!
      title = required_string(@response, "title")
      weeks = required_array(@response, "weeks")
      raise_invalid("plan must contain at least one topic") if weeks.empty?

      weeks.each do |week_data|
        validate_week(week_data)
      end

      raise_invalid("plan must contain at least one topic") if @items.empty?
      validate_daily_limits

      { title: title, items: @items }
    rescue KeyError, TypeError
      raise_invalid("plan has an invalid structure")
    end

    private

    def validate_week(week_data)
      week = week_data.fetch("week")
      topics = week_data.fetch("topics")
      raise_invalid("week must be a positive integer") unless positive_integer?(week)
      raise_invalid("week is outside the available range") if week > @study_plan.weeks_available
      raise_invalid("topics must be an array") unless topics.is_a?(Array)

      topics.each do |topic_data|
        validate_topic(topic_data, week)
      end
    end

    def validate_topic(topic_data, week)
      day = topic_data.fetch("day")
      topic = required_string(topic_data, "topic")
      duration_minutes = topic_data.fetch("duration_minutes")
      activity = required_string(topic_data, "activity")

      raise_invalid("day is not available") unless @study_plan.available_days.include?(day)
      raise_invalid("day is invalid") unless StudyPlan::WEEKDAYS.include?(day)
      raise_invalid("duration_minutes must be a positive integer") unless positive_integer?(duration_minutes)

      @items << {
        week: week,
        day: day,
        topic: topic,
        duration_minutes: duration_minutes,
        activity: activity
      }
    end

    def required_array(data, key)
      value = data.fetch(key)
      raise_invalid("#{key} must be an array") unless value.is_a?(Array)

      value
    end

    def required_string(data, key)
      value = data.fetch(key)
      raise_invalid("#{key} must be a non-empty string") unless value.is_a?(String) && value.strip != ""

      value
    end

    def positive_integer?(value)
      value.is_a?(Integer) && value.positive?
    end

    def validate_daily_limits
      daily_minutes = (@study_plan.daily_hours.to_f * 60).to_i
      @items.group_by { |item| [ item[:week], item[:day] ] }.each_value do |items|
        raise_invalid("daily duration exceeds the available time") if items.sum { |item| item[:duration_minutes] } > daily_minutes
        raise_invalid("too many topics for one day") if items.size > StudyPlanGenerator::MAX_ITEMS
      end
    end

    def raise_invalid(message)
      raise Errors::InvalidResponseError, message
    end
  end
end
