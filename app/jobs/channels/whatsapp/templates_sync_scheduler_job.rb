class Channels::Whatsapp::TemplatesSyncSchedulerJob < ApplicationJob
  queue_as :low

  def perform
    Channel::Whatsapp.joins(:account)
                     .merge(Account.active)
                     .order(Arel.sql('message_templates_last_updated IS NULL DESC, message_templates_last_updated ASC'))
                     .where('message_templates_last_updated <= ? OR message_templates_last_updated IS NULL', 3.hours.ago)
                     .where("COALESCE(provider_config->'jrc_template_settings'->>'last_attempt_at', '') <= ?", 3.hours.ago.utc.iso8601)
                     .limit(Limits::BULK_EXTERNAL_HTTP_CALLS_LIMIT)
                     .each do |channel|
      Channels::Whatsapp::TemplatesSyncJob.perform_later(channel)
    end
  end
end
