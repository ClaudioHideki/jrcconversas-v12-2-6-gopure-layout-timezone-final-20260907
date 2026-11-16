require 'rails_helper'

RSpec.describe CannedResponses::AttachmentPolicy do
  it 'enforces the existing MIME and byte limits on the server' do
    inbox = instance_double(Inbox, channel_type: 'Channel::Whatsapp')
    [
      ['image/png', 5.megabytes, true], ['image/png', 5.megabytes + 1, false],
      ['image/webp', 1024, false], ['image/svg+xml', 1024, false], ['text/html', 1024, false],
      ['application/pdf', 1024, true], ['application/zip', 1024, false], ['image/png', 0, false]
    ].each do |type, size, allowed|
      policy = described_class.new(inbox: inbox, blob: instance_double(ActiveStorage::Blob, content_type: type, byte_size: size))
      if allowed
        expect { policy.validate! }.not_to raise_error
      else
        expect { policy.validate! }.to raise_error(CannedResponses::Delivery::Invalid, 'ATTACHMENT_NOT_ALLOWED')
      end
    end
  end

  it 'honors the installation limit and denies unknown attachment channels' do
    allow(GlobalConfigService).to receive(:load).with('MAXIMUM_FILE_UPLOAD_SIZE', 40).and_return(1)
    blob = instance_double(ActiveStorage::Blob, content_type: 'application/pdf', byte_size: 2.megabytes)
    inbox = instance_double(Inbox, channel_type: 'Channel::Api')
    expect { described_class.new(inbox: inbox, blob: blob).validate! }
      .to raise_error(CannedResponses::Delivery::Invalid, 'ATTACHMENT_NOT_ALLOWED')
    inbox = instance_double(Inbox, channel_type: 'Channel::Voice')
    expect { described_class.new(inbox: inbox, blob: blob).validate! }
      .to raise_error(CannedResponses::Delivery::Invalid, 'ATTACHMENT_NOT_ALLOWED')
  end
end
