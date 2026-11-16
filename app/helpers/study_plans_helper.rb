module StudyPlansHelper
  WEEKDAY_SHORT = {
    "Domingo" => "Dom",
    "Segunda-feira" => "Seg",
    "Terça-feira" => "Ter",
    "Quarta-feira" => "Qua",
    "Quinta-feira" => "Qui",
    "Sexta-feira" => "Sex",
    "Sábado" => "Sáb"
  }.freeze

  def weekday_label(key)
    key
  end

  def weekday_short(key)
    WEEKDAY_SHORT.fetch(key, key)
  end

  def level_label(key)
    key
  end

  def format_duration(minutes)
    hours, remaining_minutes = minutes.divmod(60)
    return "#{remaining_minutes} min" if hours.zero?

    remaining_minutes.zero? ? "#{hours}h" : "#{hours}h#{remaining_minutes.to_s.rjust(2, '0')}"
  end
end
