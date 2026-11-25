class JrcCampaigns::ScheduleWindow
  def initialize(campaign)
    @campaign = campaign
  end

  def next_time(base_time)
    zone = ActiveSupport::TimeZone[config[:timezone].presence || 'UTC']
    raise ArgumentError, 'Fuso operacional inválido.' unless zone

    days = Array(config[:days]).map(&:to_i)
    clock = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/
    unless days.any? && days.all? { |day| day.between?(0, 6) } && config[:start].to_s.match?(clock) &&
           config[:end].to_s.match?(clock) && config[:start] < config[:end]
      raise ArgumentError, 'Janela de envio inválida; nenhum disparo foi autorizado.'
    end

    time = base_time.in_time_zone(zone)
    8.times do
      start_time = zone.parse("#{time.to_date} #{config[:start]}")
      end_time = zone.parse("#{time.to_date} #{config[:end]}")
      candidate = [time, start_time].max
      return candidate.utc if allowed_day?(time) && candidate < end_time

      time = time.advance(days: 1).beginning_of_day
    end
    raise ArgumentError, 'Nenhuma janela de envio válida encontrada.'
  end

  private

  attr_reader :campaign

  def config
    campaign.sending_window.with_indifferent_access
  end

  def allowed_day?(time)
    Array(config[:days]).map(&:to_i).include?(time.wday)
  end
end
