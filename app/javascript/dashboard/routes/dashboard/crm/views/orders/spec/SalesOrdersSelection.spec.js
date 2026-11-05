import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import SalesOrdersView from '../SalesOrdersView.vue';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('dashboard/api/crm/commercialCycle', () => ({
  salesOrdersAPI: { list: vi.fn(), remove: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
const orders = Array.from({ length: 12 }, (_, index) => ({
  id: index + 1,
  order_number: `PED-${String(index + 1).padStart(3, '0')}`,
  status: 'draft',
  total_cents: 1000,
  snapshot: {},
  created_at: '2026-11-04T12:00:00Z',
  owner: { id: 1, name: 'Vendedor' },
  contact: { name: `Cliente ${index + 1}` },
}));
let wrapper;
const button = text =>
  wrapper.findAll('button').find(item => item.text().includes(text));
const mountPage = async (role = 'administrator') => {
  const store = createStore({
    getters: { getCurrentRole: () => role, getCurrentUser: () => ({ id: 1 }) },
  });
  wrapper = mount(SalesOrdersView, {
    global: {
      plugins: [store],
      stubs: { ApprovalGateBadge: true, teleport: true },
    },
  });
  await flushPromises();
};
beforeEach(() => {
  salesOrdersAPI.list.mockResolvedValue({ data: orders });
  salesOrdersAPI.remove.mockResolvedValue({ data: { removed_ids: [1] } });
  HTMLDialogElement.prototype.showModal = function showModal() {
    this.open = true;
  };
  HTMLDialogElement.prototype.close = function close() {
    this.open = false;
  };
});
afterEach(() => wrapper?.unmount());

it('retains selected ids through paging and filters and restores all rows on request', async () => {
  await mountPage();
  await wrapper.get('tbody input[type="checkbox"]').setValue(true);
  await wrapper
    .findAll('button')
    .find(item => item.text() === '›')
    .trigger('click');
  await wrapper.get('tbody input[type="checkbox"]').setValue(true);
  await button('Mostrar selecionados').trigger('click');
  expect(wrapper.findAll('tbody tr')).toHaveLength(2);
  expect(wrapper.text()).toContain('PED-001');
  expect(wrapper.text()).toContain('PED-011');
  const search = wrapper.get(
    'input[placeholder="Buscar por número, cliente ou negócio..."]'
  );
  await search.setValue('PED-011');
  expect(wrapper.findAll('tbody tr')).toHaveLength(1);
  expect(button('Mostrar todos').text()).toContain('(2)');
  await search.setValue('');
  expect(wrapper.findAll('tbody tr')).toHaveLength(2);
  await button('Mostrar todos').trigger('click');
  expect(wrapper.findAll('tbody tr')).toHaveLength(10);
  expect(button('Mostrar selecionados').text()).toContain('(2)');
});

it('requires an identified order, reason and checkbox before logical deletion', async () => {
  await mountPage();
  await wrapper.get('button[aria-label="Excluir pedido"]').trigger('click');
  const dialog = wrapper.get('dialog[open]');
  expect(dialog.text()).toContain('PED-001');
  expect(dialog.text()).toContain('Cliente 1');
  expect(
    button('Confirmar exclusão lógica').attributes('disabled')
  ).toBeDefined();
  await dialog.get('[name="removal_reason"]').setValue('Duplicado');
  await dialog.get('[name="removal_confirmed"]').setValue(true);
  await dialog.get('form').trigger('submit');
  await flushPromises();
  expect(salesOrdersAPI.remove).toHaveBeenCalledWith({
    ids: [1],
    reason: 'Duplicado',
    confirmed: true,
  });
  expect(wrapper.text()).not.toContain('PED-001');
});

it('shows protected-order errors without losing selection or rows', async () => {
  salesOrdersAPI.remove.mockRejectedValue({
    response: { data: { errors: ['Pedido vinculado a contrato.'] } },
  });
  await mountPage();
  await wrapper.get('tbody input[type="checkbox"]').setValue(true);
  await button('Excluir selecionados').trigger('click');
  await wrapper.get('[name="removal_reason"]').setValue('Revisão');
  await wrapper.get('[name="removal_confirmed"]').setValue(true);
  await wrapper.get('dialog[open] form').trigger('submit');
  await flushPromises();
  expect(wrapper.get('[role="alert"]').text()).toContain(
    'vinculado a contrato'
  );
  expect(wrapper.get('tbody input').element.checked).toBe(true);
});

it('does not expose deletion controls to an agent', async () => {
  await mountPage('agent');
  expect(wrapper.find('button[aria-label="Excluir pedido"]').exists()).toBe(
    false
  );
  expect(button('Excluir selecionados')).toBeUndefined();
});
