import { mount, flushPromises } from '@vue/test-utils';
import { reactive, nextTick } from 'vue';
import { createI18n } from 'vue-i18n';
import translations from 'dashboard/i18n/locale/pt_BR/crm.json';
import ContactPicker from '../components/shared/ContactPicker.vue';
import SalesOrderWizard from '../views/orders/SalesOrderWizard.vue';
import { isGoPureAccount } from '../useCrmTheme';

const mocks = vi.hoisted(() => ({
  route: { params: { accountId: '2' }, query: {} },
  getters: {
    getCurrentRole: 'administrator',
    getCurrentUser: { id: 9 },
    getCurrentAccount: { name: 'GoPure' },
  },
  contacts: { get: vi.fn(), search: vi.fn(), show: vi.fn() },
  products: { list: vi.fn() },
  orders: { preview: vi.fn(), create: vi.fn() },
  push: vi.fn(),
  alert: vi.fn(),
}));
vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ push: mocks.push }),
}));
vi.mock('vuex', () => ({ useStore: () => ({ getters: mocks.getters }) }));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));
vi.mock('dashboard/api/contacts', () => ({ default: mocks.contacts }));
vi.mock('dashboard/api/crm/products', () => ({ default: mocks.products }));
vi.mock('dashboard/api/agents', () => ({
  default: { get: async () => ({ data: [{ id: 9, name: 'Vendedor' }] }) },
}));
vi.mock('dashboard/api/crm/proposals', () => ({
  default: { list: async () => ({ data: [] }) },
}));
vi.mock('dashboard/api/crm/deals', () => ({
  default: { list: async () => ({ data: [] }) },
}));
vi.mock('dashboard/api/crm/commercialCycle', () => ({
  salesOrdersAPI: mocks.orders,
  contractsAPI: {},
}));

const i18n = () =>
  createI18n({
    legacy: false,
    locale: 'pt_BR',
    messages: { pt_BR: translations },
  });
const wrappers = [];
const render = (component, extra = {}) => {
  const wrapper = mount(component, {
    global: {
      plugins: [i18n()],
      stubs: { RouterLink: { template: '<a><slot /></a>' }, ...extra },
    },
  });
  wrappers.push(wrapper);
  return wrapper;
};
const button = (wrapper, text) =>
  wrapper.findAll('button').find(node => node.text().includes(text));
const forward = async wrapper => {
  await button(wrapper, 'Avançar para').trigger('click');
  await flushPromises();
};
const pickCustomer = async wrapper => {
  const picker = wrapper.findComponent({ name: 'ContactPicker' });
  picker.vm.$emit('update:modelValue', 141);
  picker.vm.$emit('select', {
    id: 141,
    name: 'Cliente real',
    phone_number: '+5511999888877',
  });
  await nextTick();
};
const pickerStub = {
  name: 'ContactPicker',
  template: '<div />',
  props: ['modelValue'],
  emits: ['select', 'update:modelValue'],
};

beforeEach(() => {
  vi.clearAllMocks();
  mocks.route = reactive({ params: { accountId: '2' }, query: {} });
  mocks.getters.getCurrentRole = 'administrator';
  mocks.contacts.get.mockResolvedValue({
    data: { payload: [{ id: 10, name: 'Página um' }], meta: { count: 94 } },
  });
  mocks.contacts.show.mockImplementation(async id => ({
    data: { payload: { id: Number(id), name: 'Cliente real' } },
  }));
  mocks.products.list.mockResolvedValue({
    data: [
      {
        id: 4,
        name: 'Produto físico',
        billing_model: 'one_time',
        unit_price_cents: 2000,
        requires_implementation: false,
      },
    ],
  });
  // The UI must show the server preview, not independently recalculate it.
  mocks.orders.preview.mockImplementation(async ({ sales_order: input }) => ({
    data: {
      items: input.items.map(item => ({
        ...item,
        one_time_cents: 2000,
        recurring_cents: 0,
      })),
      products_cents: 2000,
      total_cents: 2000,
      monthly_cents: 0,
      discount_cents: 0,
      taxes_cents: 0,
      installments: [],
    },
  }));
  mocks.orders.create.mockResolvedValue({
    data: { id: 12, order_number: 'TEST-12' },
  });
});
afterEach(() => {
  wrappers.splice(0).forEach(wrapper => wrapper.unmount());
  vi.useRealTimers();
});

describe('Customer selector across pages', () => {
  it('requests page two and selects by persistent contact ID', async () => {
    const wrapper = render(ContactPicker);
    await flushPromises();
    mocks.contacts.get.mockResolvedValueOnce({
      data: {
        payload: [
          { id: 141, name: 'Página dois', phone_number: '+5511999888877' },
        ],
        meta: { count: 94 },
      },
    });
    await button(wrapper, translations.CRM.COMMERCIAL.NEXT).trigger('click');
    await flushPromises();
    expect(mocks.contacts.get).toHaveBeenLastCalledWith(2);
    await button(wrapper, 'Página dois').trigger('click');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([141]);
    expect(wrapper.emitted('select').at(-1)[0].phone_number).toBe(
      '+5511999888877'
    );
  });

  it('searches the server and ignores stale results from the previous account', async () => {
    let resolveOld;
    mocks.contacts.get.mockReturnValueOnce(
      new Promise(resolve => {
        resolveOld = resolve;
      })
    );
    const wrapper = render(ContactPicker);
    mocks.route.params.accountId = '3';
    await nextTick();
    await flushPromises();
    resolveOld({
      data: {
        payload: [{ id: 999, name: 'Conta anterior' }],
        meta: { count: 1 },
      },
    });
    await flushPromises();
    expect(wrapper.text()).not.toContain('Conta anterior');
    vi.useFakeTimers();
    mocks.contacts.search.mockResolvedValue({
      data: {
        payload: [{ id: 700, name: 'João página 30' }],
        meta: { count: 1 },
      },
    });
    await wrapper.find('input').setValue('João');
    await vi.advanceTimersByTimeAsync(260);
    await flushPromises();
    expect(mocks.contacts.search).toHaveBeenCalledWith(
      encodeURIComponent('João'),
      1
    );
    expect(wrapper.text()).toContain('João página 30');
  });
  it('removes already displayed contacts immediately while the next account is loading', async () => {
    mocks.contacts.get.mockResolvedValueOnce({ data: {payload: [{id: 991, name: 'Contato conta anterior'}], meta: {count: 1}} });
    const wrapper = render(ContactPicker);
    await flushPromises();
    expect(wrapper.text()).toContain('Contato conta anterior');
    let finish;
    mocks.contacts.get.mockReturnValueOnce(new Promise(resolve => { finish = resolve; }));
    mocks.route.params.accountId = '3';
    await nextTick();
    expect(wrapper.text()).not.toContain('Contato conta anterior');
    finish({ data: {payload: [{id: 992, name: 'Contato conta nova'}], meta: {count: 1}} });
    await flushPromises();
    expect(wrapper.text()).toContain('Contato conta nova');
  });

});

describe('Sales order workflow', () => {
  it('explains missing customer and keeps navigation outside the scroll body', async () => {
    const wrapper = render(SalesOrderWizard, { ContactPicker: pickerStub });
    await flushPromises();
    await forward(wrapper);
    expect(wrapper.find('footer [role="alert"]').text()).toBe(
      translations.CRM.COMMERCIAL.CUSTOMER_REQUIRED
    );
    expect(wrapper.find('footer').element.parentElement).toBe(wrapper.element);
    expect(wrapper.find('footer').classes()).toContain('shrink-0');
  });

  it('skips implementation for a direct sale, preserves customer and sends cents', async () => {
    mocks.getters.getCurrentRole = 'agent';
    const wrapper = render(SalesOrderWizard, { ContactPicker: pickerStub });
    await flushPromises();
    await pickCustomer(wrapper);
    await forward(wrapper);
    expect(wrapper.text()).not.toContain(
      translations.CRM.COMMERCIAL.NEW_PRODUCT
    );
    await button(wrapper, 'Produto físico').trigger('click');
    await flushPromises();
    const itemRow = wrapper.find('tbody tr');
    await itemRow.findAll('input')[0].setValue(100);
    await itemRow.findAll('input')[1].setValue(20);
    await flushPromises();
    await forward(wrapper);
    await forward(wrapper);
    expect(wrapper.text()).toContain('Tudo pronto para finalizar');
    expect(wrapper.text()).not.toContain('Responsável interno');
    await button(wrapper, 'Finalizar pedido').trigger('click');
    await flushPromises();
    const sent = mocks.orders.create.mock.calls[0][0].sales_order;
    expect(sent.contact_id).toBe(141);
    expect(new Date(sent.sold_at).getHours()).toBe(0);
    expect(new Date(sent.sold_at).getDate()).toBe(new Date().getDate());
    expect(sent.owner_id).toBe(9);
    expect(sent.items[0]).toMatchObject({ quantity: 100, unit_cents: 2000 });
    expect(sent.snapshot.checklist).toEqual([]);
  });

  it('shows product administration only to admin and validates only implementation items', async () => {
    mocks.products.list.mockResolvedValue({
      data: [
        {
          id: 4,
          name: 'Produto físico',
          billing_model: 'one_time',
          unit_price_cents: 2000,
          requires_implementation: false,
        },
        {
          id: 5,
          name: 'Ramal',
          billing_model: 'monthly',
          unit_price_cents: 3900,
          requires_implementation: true,
        },
      ],
    });
    const wrapper = render(SalesOrderWizard, { ContactPicker: pickerStub });
    await flushPromises();
    await pickCustomer(wrapper);
    await forward(wrapper);
    expect(wrapper.text()).toContain(translations.CRM.COMMERCIAL.NEW_PRODUCT);
    await button(wrapper, 'Produto físico').trigger('click');
    await button(wrapper, 'Ramal').trigger('click');
    await flushPromises();
    await forward(wrapper);
    await forward(wrapper);
    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    expect(wrapper.find('tbody').text()).toContain('Ramal');
    expect(wrapper.find('tbody').text()).not.toContain('Produto físico');
    await forward(wrapper);
    expect(wrapper.find('footer [role="alert"]').text()).toBe(
      translations.CRM.COMMERCIAL.IMPLEMENTATION_REQUIRED
    );
    expect(mocks.orders.create).not.toHaveBeenCalled();
  });
});

describe('Tenant theme selection', () => {
  it('keeps the GoPure palette scoped and supports an explicit account setting', () => {
    expect(isGoPureAccount({ name: 'GoPure' })).toBe(true);
    expect(isGoPureAccount({ name: 'Outra Empresa' })).toBe(false);
    expect(
      isGoPureAccount({
        name: 'GoPure',
        custom_attributes: { crm_theme: 'default' },
      })
    ).toBe(false);
    expect(
      isGoPureAccount({
        name: 'Unidade',
        custom_attributes: { crm_theme: 'gopure' },
      })
    ).toBe(true);
  });
});
