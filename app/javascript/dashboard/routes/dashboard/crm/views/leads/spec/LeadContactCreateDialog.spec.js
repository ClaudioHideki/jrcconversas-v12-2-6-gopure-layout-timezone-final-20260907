import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { ref } from 'vue';
import API from 'dashboard/api/jrcCustomers';
import LeadContactCreateDialog from '../LeadContactCreateDialog.vue';

const access = vi.hoisted(() => ({ allowed: true, master: true }));
vi.mock('dashboard/api/jrcCustomers', () => ({
  default: { saveContact: vi.fn() },
}));
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions: () => access.allowed }),
}));
vi.mock('dashboard/routes/dashboard/jrcCustomers/useCustomerMaster', () => ({
  useCustomerMaster: () => ({
    enabled: ref(access.master),
    canAccess: ref(access.allowed),
    accountId: ref(1),
  }),
}));
vi.mock('dashboard/composables/useContactCreation', () => ({
  useContactCreation: () => vi.fn(),
}));

const selectCompany = vi.fn();
const ContactDialog = {
  name: 'CreateNewContactDialog',
  props: ['saving'],
  emits: ['create', 'close'],
  methods: { open: vi.fn(), onSuccess: vi.fn() },
  template:
    '<div><slot name="company" :select="selectCompany" /><slot /></div>',
  setup: () => ({ selectCompany }),
};
const CompanyDialog = {
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<section><slot /></section>',
};
const payload = {
  name: 'Pessoa QA',
  email: 'pessoa@example.test',
  phoneNumber: '+5511988887777',
  additionalAttributes: {
    city: 'São Paulo',
    socialProfiles: { linkedin: 'qa' },
  },
};
let wrapper;
beforeEach(() => {
  access.allowed = true;
  access.master = true;
});
afterEach(() => wrapper?.unmount());
const open = () => {
  wrapper = mount(LeadContactCreateDialog, {
    props: { companyId: 3, companyName: 'Empresa QA' },
    global: {
      plugins: [
        createStore({ getters: { getCurrentUser: () => ({ id: 7 }) } }),
      ],
      stubs: {
        CreateNewContactDialog: ContactDialog,
        Dialog: CompanyDialog,
        CompanyPicker: true,
        CompanyEditor: true,
      },
    },
  });
  return wrapper.findComponent(ContactDialog);
};

it('creates the complete native profile with its master company in one API operation', async () => {
  API.saveContact.mockResolvedValue({
    data: { payload: { id: 8, name: payload.name, company_id: 3 } },
  });
  const dialog = open();
  dialog.vm.$emit('create', payload);
  await flushPromises();
  expect(API.saveContact).toHaveBeenCalledExactlyOnceWith({
    name: payload.name,
    email: payload.email,
    phone_number: payload.phoneNumber,
    company_id: 3,
    additional_attributes: {
      city: 'São Paulo',
      social_profiles: { linkedin: 'qa' },
      company_name: 'Empresa QA',
    },
  });
  expect(wrapper.emitted('created')[0][0]).toMatchObject({
    id: 8,
    company_id: 3,
  });
});

it('selects a newly registered company without saving or submitting the contact prematurely', async () => {
  open();
  await wrapper.find('button').trigger('click');
  wrapper
    .findComponent({ name: 'CompanyEditor' })
    .vm.$emit('saved', { id: 9, name: 'Nova empresa QA' });
  await flushPromises();
  expect(selectCompany).toHaveBeenCalledWith({
    id: 9,
    name: 'Nova empresa QA',
  });
  expect(
    wrapper.findComponent({ name: 'CompanyPicker' }).props('modelValue')
  ).toBe(9);
  expect(API.saveContact).not.toHaveBeenCalled();
});

it('keeps validation feedback and reuses an explicitly selected duplicate without changing its company', async () => {
  const existing = {
    id: 42,
    name: 'Existente',
    company_id: 15,
    email: payload.email,
  };
  API.saveContact.mockRejectedValue({
    response: { data: { code: 'POSSIBLE_DUPLICATE', candidates: [existing] } },
  });
  open().vm.$emit('create', payload);
  await flushPromises();
  expect(wrapper.find('[role="alert"]').exists()).toBe(true);
  expect(wrapper.emitted('created')).toBeUndefined();
  await wrapper
    .findAll('button')
    .find(button => button.text().includes('Usar contato existente'))
    .trigger('click');
  expect(wrapper.emitted('created')[0][0]).toEqual(existing);
  expect(API.saveContact).toHaveBeenCalledTimes(1);
});

it('blocks repeated saves while a request is pending and ignores a late response after closing', async () => {
  let resolve;
  API.saveContact.mockImplementation(
    () =>
      new Promise(done => {
        resolve = done;
      })
  );
  const dialog = open();
  dialog.vm.$emit('create', payload);
  dialog.vm.$emit('create', payload);
  expect(API.saveContact).toHaveBeenCalledTimes(1);
  wrapper.unmount();
  resolve({ data: { payload: { id: 99 } } });
  await flushPromises();
  expect(wrapper.emitted('created')).toBeUndefined();
});

it('does not allow creation without contact permissions', async () => {
  access.allowed = false;
  open().vm.$emit('create', payload);
  await flushPromises();
  expect(API.saveContact).not.toHaveBeenCalled();
  expect(wrapper.emitted('close')).toBeTruthy();
});
