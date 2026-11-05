import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import SalesOrdersView from '../SalesOrdersView.vue';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('dashboard/api/crm/commercialCycle', () => ({
  salesOrdersAPI: { list: vi.fn(), show: vi.fn(), approve: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const pending = {
  id: 11,
  order_number: 'PED-QA-011',
  status: 'pending',
  commercial_status: 'pending',
  commercial_flow: 'simple',
  total_cents: 12345,
  monthly_cents: 0,
  snapshot: {},
  items: [],
  history: [],
  allowed_statuses: ['canceled'],
  approval: { can_approve: true },
  contact: { name: 'Cliente QA' },
  owner: { id: 2, name: 'Agente QA' },
  created_at: '2026-11-05T12:00:00Z',
};
let wrapper;
const openPage = async (role = 'administrator', record = pending) => {
  salesOrdersAPI.list.mockResolvedValue({ data: [record] });
  salesOrdersAPI.show.mockResolvedValue({ data: record });
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
  await wrapper
    .findAll('button')
    .find(button => button.text() === record.order_number)
    .trigger('click');
  await flushPromises();
};
const sidebarApproval = () =>
  wrapper
    .findAll('aside button')
    .find(button => button.text().includes('Aprovar'));
const confirmApproval = () =>
  wrapper.find('dialog[open] button[type="submit"]');

beforeEach(() => {
  HTMLDialogElement.prototype.showModal = function showModal() {
    this.open = true;
  };
  HTMLDialogElement.prototype.close = function close() {
    this.open = false;
  };
});
afterEach(() => wrapper?.unmount());

it('confirms the identified order and immediately updates its commercial status without inventing operational completion', async () => {
  salesOrdersAPI.approve.mockResolvedValue({
    data: {
      ...pending,
      status: 'approved',
      commercial_status: 'active',
      approval: { can_approve: false },
    },
  });
  await openPage();
  expect(sidebarApproval().text()).toBe('Aprovar e ativar pedido');
  await sidebarApproval().trigger('click');
  expect(wrapper.find('dialog[open]').text()).toContain('PED-QA-011');
  expect(wrapper.find('dialog[open]').text()).toContain('Cliente QA');
  expect(salesOrdersAPI.approve).not.toHaveBeenCalled();
  expect(confirmApproval().attributes('type')).toBe('submit');
  await wrapper.find('dialog[open] form').trigger('submit');
  await flushPromises();
  expect(salesOrdersAPI.approve).toHaveBeenCalledExactlyOnceWith(11);
  expect(wrapper.findAll('aside').at(-1).text()).toContain('Ativo');
  expect(sidebarApproval()).toBeUndefined();
  expect(wrapper.findAll('aside').at(-1).text()).toContain(
    'Faturamento e entrega são acompanhados separadamente.'
  );
});

it('does not show approval to an agent even when a stale response claims approval is available', async () => {
  await openPage('agent');
  expect(sidebarApproval()).toBeUndefined();
  expect(salesOrdersAPI.approve).not.toHaveBeenCalled();
});

it('keeps the confirmation and the pending order intact when a commercial gate blocks approval', async () => {
  salesOrdersAPI.approve.mockRejectedValue({
    response: { status: 409, data: { code: 'APPROVAL_REQUIRED' } },
  });
  await openPage();
  await sidebarApproval().trigger('click');
  await wrapper.find('dialog[open] form').trigger('submit');
  await flushPromises();
  expect(wrapper.find('dialog[open] [role="alert"]').text()).toContain(
    'alçada pendentes'
  );
  expect(wrapper.findAll('aside').at(-1).text()).toContain('Pendente');
  expect(salesOrdersAPI.approve).toHaveBeenCalledTimes(1);
});

it('cancels the confirmation without approving', async () => {
  await openPage();
  await sidebarApproval().trigger('click');
  await wrapper
    .find('dialog[open]')
    .find('button[type="button"]')
    .trigger('click');
  expect(salesOrdersAPI.approve).not.toHaveBeenCalled();
});

it('preserves the operational workflow for a standard account', async () => {
  await openPage('administrator', { ...pending, commercial_flow: 'standard' });
  expect(sidebarApproval().text()).toBe('Aprovar pedido');
  expect(wrapper.findAll('aside').at(-1).text()).toContain('Em implantação');
  expect(wrapper.findAll('aside').at(-1).text()).not.toContain(
    'Ativo indica aprovação comercial.'
  );
});

it('preserves submitting a GoPure draft for approval without exposing operational completion actions', async () => {
  await openPage('administrator', {
    ...pending,
    status: 'draft',
    commercial_status: 'draft',
    allowed_statuses: ['pending', 'canceled'],
    approval: { can_approve: false },
  });
  expect(sidebarApproval()).toBeUndefined();
  const actions = wrapper.findAll('aside button').map(button => button.text());
  expect(actions).toContain('Pendente');
  expect(actions).toContain('Cancelar pedido');
  expect(actions).not.toContain('Em implantação');
});
