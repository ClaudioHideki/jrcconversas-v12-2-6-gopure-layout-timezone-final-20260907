require 'rails_helper'
RSpec.describe JrcCrm::StageReorderInput do
  it 'preserves valid integer identifiers and positions' do
    expect(described_class.call([{ id: '12', position: '2' }, { id: 13, position: 1 }])).to eq([[12, 13], [2, 1]])
  end
  it 'rejects fractional or malformed identifiers instead of truncating them' do
    [1.5, '12x', 0, -1, nil].each do |value|
      expect { described_class.call([{ id: value, position: 1 }]) }.to raise_error(ArgumentError)
      expect { described_class.call([{ id: 12, position: value }]) }.to raise_error(ArgumentError)
    end
  end
  it 'rejects duplicate positions and malformed payloads' do
    expect { described_class.call([{ id: 12, position: 1 }, { id: 13, position: 1 }]) }.to raise_error(ArgumentError)
    expect { described_class.call('invalid') }.to raise_error(ArgumentError)
  end
end
