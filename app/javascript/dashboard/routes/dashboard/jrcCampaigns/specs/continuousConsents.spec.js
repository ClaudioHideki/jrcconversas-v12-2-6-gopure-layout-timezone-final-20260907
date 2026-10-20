import { flushPromises, mount } from '@vue/test-utils';
import ConsentPanel from '../components/ConsentPanel.vue';
import api from 'dashboard/api/jrcCampaigns';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/jrcCampaigns', () => ({
  default: {
    consents: vi.fn(),
    createConsent: vi.fn(),
    revokeConsent: vi.fn(),
  },
}));

describe('Continuous recipient consent', () => {
  let wrapper;
  beforeEach(() => {
    vi.clearAllMocks();
    api.consents.mockResolvedValue({ data: [] });
    api.createConsent.mockResolvedValue({ data: { id: 5 } });
    api.revokeConsent.mockResolvedValue({});
    wrapper = mount(ConsentPanel, {
      global: { stubs: { TestAuthorizationPanel: true } },
    });
  });
  afterEach(() => wrapper.unmount());

  it('shows continuous consent first and keeps single-test permission optional', () => {
    expect(wrapper.find('h2').text()).toBe(
      'JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_TITLE'
    );
    expect(wrapper.find('details').attributes('open')).toBeUndefined();
  });

  it('requires explicit confirmation of recurring tests and campaigns', async () => {
    await wrapper
      .find('input:not([type="checkbox"])')
      .setValue('5511999999000');
    await wrapper
      .find('textarea')
      .setValue('Synthetic recipient permits recurring tests and campaigns.');
    expect(
      wrapper.find('button[type="submit"]').attributes('disabled')
    ).toBeDefined();
    await wrapper.find('form').trigger('submit');
    expect(api.createConsent).not.toHaveBeenCalled();
  });

  it('records one continuous authorization rather than a single-test grant', async () => {
    await wrapper
      .find('input:not([type="checkbox"])')
      .setValue('5511999999000');
    await wrapper
      .find('textarea')
      .setValue('Synthetic recipient permits recurring tests and campaigns.');
    await wrapper.find('input[type="checkbox"]').setValue(true);
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(api.createConsent).toHaveBeenCalledExactlyOnceWith({
      phone_number: '5511999999000',
      evidence: 'Synthetic recipient permits recurring tests and campaigns.',
      operator_confirmed: true,
      supersedes_id: null,
    });
    expect(wrapper.find('input[type="checkbox"]').element.checked).toBe(false);
  });

  it('asks for fresh evidence when confirming a historical phone without altering it', async () => {
    api.consents.mockResolvedValue({
      data: [
        {
          id: 2,
          phone_number: '+5511999999000',
          evidence: 'Original evidence',
          purpose: null,
        },
      ],
    });
    await wrapper.vm.load();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'JRC_CAMPAIGNS.GOVERNANCE.RECONFIRM')
      .trigger('click');
    expect(wrapper.find('input:not([type="checkbox"])').element.value).toBe(
      '+5511999999000'
    );
    expect(wrapper.find('textarea').element.value).toBe('');
    expect(wrapper.find('input[type="checkbox"]').element.checked).toBe(false);
    expect(wrapper.text()).toContain('Original evidence');
    expect(api.createConsent).not.toHaveBeenCalled();
    await wrapper
      .find('textarea')
      .setValue('New explicit holder confirmation with date and reference.');
    await wrapper.find('input[type="checkbox"]').setValue(true);
    await wrapper.find('form').trigger('submit');
    expect(api.createConsent.mock.calls[0][0].supersedes_id).toBe(2);
  });

  it('requires confirmation again if the destination changes', async () => {
    await wrapper
      .find('input:not([type="checkbox"])')
      .setValue('5511999999000');
    await wrapper.find('input[type="checkbox"]').setValue(true);
    await wrapper
      .find('input:not([type="checkbox"])')
      .setValue('5511999999001');
    expect(wrapper.find('input[type="checkbox"]').element.checked).toBe(false);
  });

  it('shows continuous and historical scope explicitly and permits revocation', async () => {
    api.consents.mockResolvedValue({
      data: [
        {
          id: 5,
          phone_number: '+5511999999000',
          evidence: 'New recurring scope',
          purpose: 'whatsapp_campaigns',
          supersedes_id: 2,
        },
        {
          id: 2,
          phone_number: '+5511999999000',
          evidence: 'Old evidence',
          revoked_at: '2026-10-20',
          superseded_by_id: 5,
        },
      ],
    });
    await wrapper.vm.load();
    expect(wrapper.text()).toContain(
      'JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_ACTIVE'
    );
    expect(wrapper.text()).toContain('JRC_CAMPAIGNS.GOVERNANCE.SUPERSEDED');
    const revokeButtons = wrapper
      .findAll('button')
      .filter(button => button.text() === 'JRC_CAMPAIGNS.GOVERNANCE.REVOKE');
    expect(revokeButtons).toHaveLength(1);
    await revokeButtons[0].trigger('click');
    expect(api.revokeConsent).toHaveBeenCalledExactlyOnceWith(5);
  });
});
