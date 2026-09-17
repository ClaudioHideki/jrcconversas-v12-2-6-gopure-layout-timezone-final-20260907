import { mount, flushPromises } from '@vue/test-utils';
import { useRouter } from 'vue-router';
import { leadsAPI } from 'dashboard/api/crm';
import ContactLeadAction from '../ContactLeadAction.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: vi.fn(),
}));
vi.mock('dashboard/api/crm', () => ({
  leadsAPI: { forContact: vi.fn(), create: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountAction = () =>
  mount(ContactLeadAction, {
    props: { contact: { id: 141, name: 'Thiago' } },
    global: {
      stubs: { LeadCreateModal: true },
    },
  });

describe('Contact lead action', () => {
  it('opens the shared prefilled form and becomes View Lead after saving', async () => {
    leadsAPI.forContact.mockResolvedValue({
      data: { linked: false, lead_id: null },
    });
    const wrapper = mountAction();
    await flushPromises();
    expect(wrapper.get('button').text()).toBe('+ Criar Lead');
    await wrapper.get('button').trigger('click');
    const modal = wrapper.getComponent({ name: 'LeadCreateModal' });
    expect(modal.props('contact').id).toBe(141);
    modal.vm.$emit('created', { id: 33, contact_id: 141 });
    await flushPromises();
    expect(wrapper.get('button').text()).toBe('Ver Lead');
    expect(wrapper.emitted('created')[0][0].contact_id).toBe(141);
  });

  it('opens the correct existing lead instead of offering creation', async () => {
    const push = vi.fn();
    useRouter.mockReturnValue({ push });
    leadsAPI.forContact.mockResolvedValue({
      data: { linked: true, lead_id: 33 },
    });
    const wrapper = mountAction();
    await flushPromises();
    await wrapper.get('button').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'crm_leads',
      params: { accountId: '1' },
      query: { leadId: 33 },
    });
    expect(wrapper.findComponent({ name: 'LeadCreateModal' }).exists()).toBe(
      false
    );
  });

  it('blocks creation and access when another agent owns the lead', async () => {
    leadsAPI.forContact.mockResolvedValue({
      data: { linked: true, lead_id: null },
    });
    const wrapper = mountAction();
    await flushPromises();
    expect(wrapper.get('button').element.disabled).toBe(true);
    expect(wrapper.text()).toContain('solicite acesso ao administrador');
  });

  it('does not offer creation when lookup fails and permits retry', async () => {
    leadsAPI.forContact.mockRejectedValueOnce(new Error('network'));
    const wrapper = mountAction();
    await flushPromises();
    expect(wrapper.text()).toContain('Tentar novamente');
    leadsAPI.forContact.mockResolvedValue({
      data: { linked: false, lead_id: null },
    });
    await wrapper.get('button').trigger('click');
    await flushPromises();
    expect(wrapper.get('button').text()).toBe('+ Criar Lead');
  });

  it('ignores stale lookup responses when another contact is selected', async () => {
    let resolveFirst;
    leadsAPI.forContact
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFirst = resolve;
          })
      )
      .mockResolvedValueOnce({ data: { linked: false, lead_id: null } });
    const wrapper = mountAction();
    await wrapper.setProps({ contact: { id: 142, name: 'Outro' } });
    await flushPromises();
    resolveFirst({ data: { linked: true, lead_id: 33 } });
    await flushPromises();
    expect(wrapper.get('button').text()).toBe('+ Criar Lead');
  });
});
