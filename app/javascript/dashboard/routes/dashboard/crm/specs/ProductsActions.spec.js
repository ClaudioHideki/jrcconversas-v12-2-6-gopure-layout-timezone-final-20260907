import { shallowMount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import { productsAPI } from 'dashboard/api/crm';
import ProductsIndex from '../views/products/ProductsIndex.vue';
import productsModule from 'dashboard/store/crm/modules/products';
import messages from 'dashboard/i18n/locale/en/crm.json';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({
  productsAPI: {
    create: vi.fn(),
    list: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    toggleActive: vi.fn(),
  },
  proposalsAPI: {
    creationOptions: vi
      .fn()
      .mockResolvedValue({ data: { business_units: [] } }),
  },
}));

const copy = messages.CRM.PRODUCT_ACTIONS;
let wrapper;
let store;
let product;
beforeEach(() => {
  vi.clearAllMocks();
  sessionStorage.clear();
  product = {
    id: 7,
    name: 'Synthetic product',
    sku: 'SYNTHETIC-7',
    product_type: 'product',
    billing_model: 'one_time',
    unit_price_cents: 5990,
    cost_cents: 1904,
    active: true,
    document_rules: [
      {
        key: 'synthetic',
        label: 'Original document',
        source: 'manual',
        required: true,
        blocking: false,
      },
    ],
  };
  productsAPI.list.mockResolvedValue({ data: [product] });
  productsAPI.update.mockResolvedValue({ data: product });
  productsAPI.delete.mockResolvedValue({});
});
afterEach(() => wrapper?.unmount());
const mountPage = async (role = 'administrator') => {
  store = createStore({
    getters: { getCurrentRole: () => role, getCurrentUser: () => ({ id: 1 }) },
    modules: {
      jrcCrm: {
        namespaced: true,
        modules: {
          products: {
            ...productsModule,
            state: { products: [], isLoading: false },
          },
        },
      },
    },
  });
  wrapper = shallowMount(ProductsIndex, {
    global: {
      stubs: { CrmPageHeader: false },
      plugins: [
        store,
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
    },
  });
  await flushPromises();
};

it('edits a real Vuex reactive product without cloning errors or mutating the catalog draft', async () => {
  await mountPage();
  await wrapper.get('[aria-label="Editar produto"]').trigger('click');
  expect(wrapper.get('form').text()).toContain('Editar produto ou serviço');
  const name = wrapper
    .findAll('form input')
    .find(input => input.element.value === product.name);
  await name.setValue('Reviewed product');
  const documents = wrapper
    .findAll('form nav button')
    .find(button => button.text().includes('Documentos'));
  await documents.trigger('click');
  await wrapper
    .get('input[placeholder="Nome do requisito"]')
    .setValue('Reviewed document');
  expect(
    store.getters['jrcCrm/products/allProducts'][0].document_rules[0].label
  ).toBe('Original document');
  productsAPI.list.mockResolvedValue({
    data: [{ ...product, name: 'Reviewed product' }],
  });
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(productsAPI.update).toHaveBeenCalledWith(7, {
    product: expect.objectContaining({
      name: 'Reviewed product',
      unit_price_cents: 5990,
      document_rules: [expect.objectContaining({ label: 'Reviewed document' })],
    }),
  });
  expect(wrapper.find('form').exists()).toBe(false);
  expect(wrapper.text()).toContain('Reviewed product');
});

it('requires confirmation, allows cancellation and refreshes the catalog after deletion', async () => {
  await mountPage();
  await wrapper.get(`[aria-label="${copy.DELETE}"]`).trigger('click');
  expect(productsAPI.delete).not.toHaveBeenCalled();
  await wrapper
    .findAll('[role="alertdialog"] button')
    .find(button => button.text() === copy.CANCEL)
    .trigger('click');
  expect(wrapper.find('[role="alertdialog"]').exists()).toBe(false);
  await wrapper.get(`[aria-label="${copy.DELETE}"]`).trigger('click');
  productsAPI.list.mockResolvedValue({ data: [] });
  await wrapper
    .findAll('[role="alertdialog"] button')
    .find(button => button.text() === copy.CONFIRM)
    .trigger('click');
  await flushPromises();
  expect(productsAPI.delete).toHaveBeenCalledExactlyOnceWith(7);
  expect(wrapper.find('[role="alertdialog"]').exists()).toBe(false);
  expect(wrapper.text()).not.toContain('Synthetic product');
});

it('keeps the product and explains protected links when deletion is rejected', async () => {
  productsAPI.delete.mockRejectedValue({
    response: { data: { errors: ['Protected order link'] } },
  });
  await mountPage();
  await wrapper.get(`[aria-label="${copy.DELETE}"]`).trigger('click');
  await wrapper
    .findAll('[role="alertdialog"] button')
    .find(button => button.text() === copy.CONFIRM)
    .trigger('click');
  await flushPromises();
  expect(wrapper.get('[role="alert"]').text()).toBe('Protected order link');
  expect(wrapper.text()).toContain('Synthetic product');
});

it('blocks duplicate deletion and disables the other actions while deleting', async () => {
  let finish;
  productsAPI.delete.mockReturnValue(
    new Promise(resolve => {
      finish = resolve;
    })
  );
  await mountPage();
  await wrapper.get(`[aria-label="${copy.DELETE}"]`).trigger('click');
  const confirm = wrapper
    .findAll('[role="alertdialog"] button')
    .find(button => button.text() === copy.CONFIRM);
  await confirm.trigger('click');
  await confirm.trigger('click');
  expect(productsAPI.delete).toHaveBeenCalledOnce();
  expect(
    wrapper.get('[aria-label="Editar produto"]').attributes('disabled')
  ).toBeDefined();
  finish({});
  await flushPromises();
});

it('keeps activation separate from deletion', async () => {
  await mountPage();
  await wrapper.get('[aria-label="Desativar produto"]').trigger('click');
  await flushPromises();
  expect(productsAPI.toggleActive).toHaveBeenCalledExactlyOnceWith(7);
  expect(productsAPI.delete).not.toHaveBeenCalled();
});

it('does not expose edit or deletion actions to an agent', async () => {
  await mountPage('agent');
  expect(wrapper.find('[aria-label="Editar produto"]').exists()).toBe(false);
  expect(wrapper.find(`[aria-label="${copy.DELETE}"]`).exists()).toBe(false);
});

it('imports CSV rows sequentially and continues after an individual row failure', async () => {
  await mountPage();
  const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true);
  let failFirst;
  productsAPI.create
    .mockImplementationOnce(
      () =>
        new Promise((_resolve, reject) => {
          failFirst = reject;
        })
    )
    .mockResolvedValue({});
  const input = wrapper.get('input[type="file"]');
  Object.defineProperty(input.element, 'files', {
    configurable: true,
    value: [
      {
        text: async () =>
          'Nome;SKU;Preço\nFirst synthetic;CSV-1;10,00\nSecond synthetic;CSV-2;20,00',
      },
    ],
  });
  await input.trigger('change');
  await flushPromises();
  expect(productsAPI.create).toHaveBeenCalledOnce();
  expect(productsAPI.create.mock.calls[0][0].product.name).toBe(
    'First synthetic'
  );
  failFirst({ response: { data: { errors: ['Synthetic rejection'] } } });
  await flushPromises();
  expect(productsAPI.create).toHaveBeenCalledTimes(2);
  expect(productsAPI.create.mock.calls[1][0].product.name).toBe(
    'Second synthetic'
  );
  confirm.mockRestore();
});
