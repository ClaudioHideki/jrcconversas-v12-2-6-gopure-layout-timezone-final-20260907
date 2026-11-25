require 'rails_helper'

RSpec.describe JrcCampaigns::ScheduleWindow do
  let(:campaign) do
    instance_double(JrcCampaigns::Campaign,
                    sending_window: { 'start' => '08:00', 'end' => '18:00', 'days' => [1, 2, 3, 4, 5], 'timezone' => 'America/Sao_Paulo' })
  end
  let(:window) { described_class.new(campaign) }

  it 'reproduces 25 November 2026 at 19:21 UTC as eligible at 16:21 Sao Paulo' do
    time = Time.utc(2026, 11, 25, 19, 21)
    expect(window.next_time(time)).to eq(time)
  end

  it 'opens at 08:00 local, not 08:00 UTC' do
    expect(window.next_time(Time.utc(2026, 11, 25, 9))).to eq(Time.utc(2026, 11, 25, 11))
  end

  it 'moves an evening job to the next allowed opening' do
    expect(window.next_time(Time.utc(2026, 11, 25, 22))).to eq(Time.utc(2026, 11, 26, 11))
  end

  it 'moves Friday evening across the weekend' do
    expect(window.next_time(Time.utc(2026, 11, 27, 22))).to eq(Time.utc(2026, 11, 30, 11))
  end

  it 'fails closed for an invalid window rather than returning the input time' do
    allow(campaign).to receive(:sending_window).and_return({ 'start' => '08:00', 'end' => '18:00', 'days' => [], 'timezone' => 'UTC' })
    expect { window.next_time(Time.utc(2026, 11, 25, 22)) }.to raise_error(ArgumentError)
  end

  it 'keeps legacy windows in UTC until an operator reviews their timezone' do
    allow(campaign).to receive(:sending_window).and_return({ 'start' => '08:00', 'end' => '18:00', 'days' => [1, 2, 3, 4, 5] })
    expect(window.next_time(Time.utc(2026, 11, 25, 19))).to eq(Time.utc(2026, 11, 26, 8))
  end

  it 'handles DST in New York without a fixed UTC offset' do
    allow(campaign).to receive(:sending_window).and_return({ 'start' => '08:00', 'end' => '18:00', 'days' => [0, 1, 2, 3, 4, 5, 6],
                                                             'timezone' => 'America/New_York' })
    expect(window.next_time(Time.utc(2026, 3, 8, 10))).to eq(Time.utc(2026, 3, 8, 12))
    expect(window.next_time(Time.utc(2026, 11, 1, 10))).to eq(Time.utc(2026, 11, 1, 13))
  end
end
