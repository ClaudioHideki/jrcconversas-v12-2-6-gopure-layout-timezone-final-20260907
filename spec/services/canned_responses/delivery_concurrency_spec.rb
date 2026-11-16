require 'rails_helper'
require 'timeout'

RSpec.describe 'Quick reply persistent delivery intents', type: :model do
  self.use_transactional_tests = false
  let(:account) { create(:account, name: 'Synthetic quick reply concurrency') }
  let(:actor) { create(:user, account: account, role: :administrator) }

  after do
    # Remove only this committed synthetic fixture using the native association
    # teardown. Provider delivery jobs must never run in this test.
    perform_enqueued_jobs(only: ActiveRecord::DestroyAssociationAsyncJob) do
      account.contacts.each(&:destroy!)
      account.destroy!
    end
    actor.destroy!
  end

  it 'serializes two independent database connections into one native message and attachment' do
    raise 'ISOLATED_TEST_REQUIRED' unless Rails.env.test?

    conversation = create(:conversation, account: account).reload
    canned = create(:canned_response, account: account, content: 'Synthetic concurrent text')
    canned.file.attach(io: File.open(Rails.root.join('spec/assets/sample.pdf')), filename: 'synthetic.pdf', content_type: 'application/pdf')
    revision = canned.reload.updated_at.iso8601(6)
    context = CannedResponses::Preview.context_for(conversation)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do |connection|
          ready << connection.select_value('SELECT pg_backend_pid()')
          start.pop
          begin
            result = CannedResponses::Delivery.new(response: CannedResponse.find(canned.id),
                                                   conversation: Conversation.find(conversation.id), user: actor).call(
                                                     content: 'Synthetic concurrent text', key: 'synthetic-concurrent-delivery',
                                                     expected_actor_id: actor.id,
                                                     expected_context: context, confirmed: true, revision: revision
                                                   )
            results << [:ok, result.id]
          rescue StandardError => e
            results << [:error, e.class.name, e.message]
          end
        end
      end
    end
    Timeout.timeout(20) do
      expect(Array.new(2) { ready.pop }.uniq.size).to eq(2)
      2.times { start << true }
      threads.each(&:join)
      outcomes = Array.new(2) { results.pop }
      expect(outcomes.map(&:first)).to eq(%i[ok ok]), outcomes.inspect
      expect(outcomes.map(&:last).uniq.size).to eq(1)
    end
    expect(conversation.messages.outgoing.count).to eq(1)
    sent = conversation.messages.outgoing.sole.attachments.sole
    expect(sent.file.download).to eq(canned.file.download)
    expect(sent.file.blob_id).not_to eq(canned.file.blob_id)
    jobs = enqueued_jobs.select { |job| job[:job] == SendReplyJob && job[:args].first == sent.message_id }
    expect(jobs.length).to eq(1)
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end
end
