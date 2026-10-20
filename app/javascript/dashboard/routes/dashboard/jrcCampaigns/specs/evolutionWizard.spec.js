import { mount, flushPromises } from '@vue/test-utils';
import CampaignWizard from '../components/CampaignWizard.vue';
import api from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/jrcCampaigns', () => ({
  default: {
    audiencePreview: vi.fn(),
    testMessage: vi.fn(),
    testDelivery: vi.fn(),
  },
}));

describe('Evolution campaign test confirmation', () => {
  let wrapper;
  beforeEach(() => {
    vi.clearAllMocks();
    api.audiencePreview.mockResolvedValue({
      data: { estimated_recipients: 1, sample: [] },
    });
    api.testMessage.mockResolvedValue({
      data: { test_delivery_id: 7, message_id: 'provider-id', status: 'sent' },
    });
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    wrapper = mount(CampaignWizard, {
      props: {
        metadata: {
          whatsapp_inboxes: [
            {
              id: 8,
              name: 'WhatsApp Demo',
              connector: 'evolution',
              phone_number: '551155550000',
              min_interval_seconds: 60,
            },
          ],
          source_inboxes: [],
        },
        campaign: {
          id: 1,
          name: 'QA',
          campaign_inboxes: [{ inbox_id: 8, enabled: true }],
          steps: [{ kind: 'text', body: 'Teste', position: 0 }],
        },
      },
      global: { mocks: { $t: key => key } },
    });
    wrapper.vm.testDestination = '5511999999000';
  });
  afterEach(() => {
    wrapper.unmount();
    vi.restoreAllMocks();
  });

  it('does not send when the operator declines confirmation', async () => {
    window.confirm.mockReturnValue(false);
    await wrapper.vm.sendTest();
    expect(api.testMessage).not.toHaveBeenCalled();
  });

  it('reuses the idempotency key and displays accepted rather than delivered', async () => {
    await wrapper.vm.sendTest();
    await wrapper.vm.sendTest();
    const first = api.testMessage.mock.calls[0][0];
    const second = api.testMessage.mock.calls[1][0];
    expect(first).toMatchObject({
      inbox_id: 8,
      phone_number: '5511999999000',
      operator_confirmed: true,
    });
    expect(second.idempotency_key).toBe(first.idempotency_key);
    expect(useAlert).toHaveBeenCalledWith(
      'JRC_CAMPAIGNS.EVOLUTION.TEST_ACCEPTED'
    );
    await flushPromises();
    expect(wrapper.text()).toContain('JRC_CAMPAIGNS.EVOLUTION.TEST_RESULT');
  });

  it('does not tell the operator an unknown result was sent', async () => {
    api.testMessage.mockResolvedValue({
      data: { test_delivery_id: 7, status: 'unknown' },
    });
    await wrapper.vm.sendTest();
    expect(useAlert).toHaveBeenCalledWith(
      'JRC_CAMPAIGNS.EVOLUTION.TEST_UNCONFIRMED'
    );
    expect(useAlert).not.toHaveBeenCalledWith('JRC_CAMPAIGNS.ALERTS.TEST_SENT');
  });
});
