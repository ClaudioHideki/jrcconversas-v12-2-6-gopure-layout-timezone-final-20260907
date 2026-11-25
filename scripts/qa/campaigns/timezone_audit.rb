# Read-only inventory. Never invokes launch/resume, performs sends or reschedules.
# Usage: ACCOUNT_ID=<authorized account> bundle exec rails runner scripts/qa/campaigns/timezone_audit.rb
require 'json'

account_id = Integer(ENV.fetch('ACCOUNT_ID'), 10)
ActiveRecord::Base.while_preventing_writes do
  account = Account.find(account_id)
  report = account.jrc_campaigns.where(status: %w[running paused scheduled]).order(:id).map do |campaign|
    zone = campaign.sending_window['timezone'].presence || 'UTC'
    next_time = JrcCampaigns::ScheduleWindow.new(campaign).next_time(Time.current)
    { campaign_id: campaign.id, status: campaign.status, timezone: zone,
      legacy_timezone_requires_review: campaign.sending_window['timezone'].blank?,
      next_eligible_utc: next_time.iso8601, next_eligible_local: next_time.in_time_zone(zone).iso8601,
      queued: campaign.recipients.where(status: 'queued').count,
      accepted_or_sent: campaign.recipients.where.not(sent_at: nil).count,
      scheduled_at_utc: campaign.scheduled_at&.utc&.iso8601,
      approval_expires_at: campaign.approval_expires_at&.utc&.iso8601 }
  end
  puts JSON.pretty_generate(account_id: account.id, generated_at_utc: Time.current.utc.iso8601, read_only: true, campaigns: report)
end
