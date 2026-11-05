import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n';
import Lead from '../LeadCreateModal.vue';
import API from 'dashboard/api/jrcCustomers';
import { leadsAPI } from 'dashboard/api/crm';

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions: () => true }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({ leadsAPI: { create: vi.fn() } }));
vi.mock('dashboard/api/jrcCustomers', () => ({
  default: {
    metadata: vi.fn(),
    companies: vi.fn(),
    company: vi.fn(),
    saveCompany: vi.fn(),
    saveContact: vi.fn(),
  },
}));

it('runs the real lead, native contact and master company forms end to end with synthetic data', async () => {
  sessionStorage.clear();
  const unrelatedDraft = JSON.stringify({
    version: 1,
    data: { firstName: 'Outro cadastro' },
  });
  sessionStorage.setItem(
    'jrc:draft:account:1:user:7:crm:native_contact',
    unrelatedDraft
  );
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute('open', '');
  };
  HTMLDialogElement.prototype.close = function () {
    this.removeAttribute('open');
  };
  const company = {
    id: 7,
    name: 'Empresa de teste QA',
    relationship_type: 'prospect',
  };
  const contact = {
    id: 42,
    name: 'Pessoa QA',
    email: 'pessoa@example.test',
    company_id: 7,
    company_name: company.name,
  };
  API.metadata.mockResolvedValue({ data: { owners: [], segments: [] } });
  API.companies.mockResolvedValue({
    data: { payload: [], meta: { total: 0 } },
  });
  API.company.mockResolvedValue({ data: { payload: company } });
  API.saveCompany.mockResolvedValue({ data: { payload: company } });
  API.saveContact.mockResolvedValue({ data: { payload: contact } });
  leadsAPI.create.mockResolvedValue({
    status: 201,
    data: { id: 99, contact_id: 42, company_id: 7 },
  });
  const user = {
    id: 7,
    accounts: [
      {
        id: 1,
        role: 'administrator',
        permissions: ['jrc_crm', 'contact_manage'],
      },
    ],
  };
  const store = createStore({
    getters: {
      getCurrentUser: () => user,
      getCurrentUserID: () => 7,
      getCurrentRole: () => 'administrator',
      'contacts/getUIFlags': () => ({}),
      'accounts/isRTL': () => false,
      'accounts/isFeatureEnabledonAccount': () => (id, feature) =>
        feature === 'jrc_customer_master',
      'accounts/getAccount': () => () => ({ id: 1, locale: 'pt_BR' }),
    },
  });
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/app/accounts/:accountId/crm/leads',
        name: 'crm_leads',
        component: { template: '<div />' },
      },
    ],
  });
  await router.push('/app/accounts/1/crm/leads');
  await router.isReady();
  const wrapper = mount(Lead, {
    attachTo: document.body,
    global: {
      stubs: { teleport: true },
      plugins: [
        store,
        router,
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          fallbackLocale: 'en',
          missingWarn: false,
          fallbackWarn: false,
          messages,
        }),
      ],
    },
  });
  await flushPromises();
  await wrapper.get('[name="notes"]').setValue('Acompanhamento preservado QA');
  await wrapper
    .findAll('button')
    .find(x => x.text() === 'Criar cliente')
    .trigger('click');
  await flushPromises();
  const form = wrapper.findComponent({ name: 'ContactsForm' });
  await form.findAll('input')[0].setValue('Pessoa');
  await form.findAll('input')[1].setValue('QA');
  await form.findAll('input')[2].setValue('pessoa@example.test');
  await wrapper
    .findAll('button')
    .find(x => x.text() === 'Cadastrar nova empresa')
    .trigger('click');
  await flushPromises();
  const editor = wrapper.findComponent({ name: 'CompanyEditor' });
  await editor.find('input').setValue(company.name);
  await editor.find('form').trigger('submit');
  await flushPromises();
  await flushPromises();
  expect(API.saveCompany).toHaveBeenCalledTimes(1);
  expect(
    wrapper
      .findAllComponents({ name: 'CompanyPicker' })
      .find(picker => picker.props('modelValue') === 7)
      .text()
  ).toContain(company.name);
  expect(API.saveContact).not.toHaveBeenCalled();
  wrapper
    .findComponent({ name: 'CreateNewContactDialog' })
    .vm.dialogRef.$emit('confirm');
  await flushPromises();
  expect(API.saveContact).toHaveBeenCalledTimes(1);
  expect(API.saveContact.mock.calls[0][0]).toMatchObject({
    name: 'Pessoa QA',
    email: contact.email,
    company_id: 7,
  });
  expect(wrapper.get('[name="notes"]').element.value).toBe(
    'Acompanhamento preservado QA'
  );
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(leadsAPI.create).toHaveBeenCalledWith({
    lead: expect.objectContaining({
      contact_id: 42,
      company_id: 7,
      notes: 'Acompanhamento preservado QA',
    }),
  });
  expect(
    sessionStorage.getItem('jrc:draft:account:1:user:7:crm:native_contact')
  ).toBe(unrelatedDraft);
  wrapper.unmount();
});
