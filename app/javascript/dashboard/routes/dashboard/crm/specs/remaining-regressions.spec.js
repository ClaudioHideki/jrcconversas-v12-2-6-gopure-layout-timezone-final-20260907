import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import { createI18n } from 'vue-i18n';
import translations from 'dashboard/i18n/locale/pt_BR/crm.json';
import DealsIndex from '../views/deals/DealsIndex.vue';
import GoalsView from '../views/goals/GoalsView.vue';

const mocks = vi.hoisted(() => ({
  route: {},
  contacts: { get: vi.fn(), search: vi.fn(), show: vi.fn() },
  deals: { create: vi.fn() },
  goals: { list: vi.fn(), dashboard: vi.fn() },
  dispatch: vi.fn(),
  alert: vi.fn(),
}));
vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('vuex', () => ({
  useStore: () => ({ getters: {}, dispatch: mocks.dispatch, commit: vi.fn() }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));
vi.mock('dashboard/api/contacts', () => ({ default: mocks.contacts }));
vi.mock('dashboard/api/agents', () => ({
  default: { get: async () => ({ data: [] }) },
}));
vi.mock('dashboard/api/crm/products', () => ({
  default: { list: async () => ({ data: [] }) },
}));
vi.mock('dashboard/api/crm', () => ({
  dealsAPI: mocks.deals,
  pipelinesAPI: { list: async () => ({ data: [{ id: 1, name: 'Funil' }] }) },
  stagesAPI: { list: async () => ({ data: [{ id: 2, name: 'Inicial' }] }) },
  productsAPI: { list: async () => ({ data: [] }) },
  activitiesAPI: {},
}));
vi.mock('dashboard/api/crm/commercialCycle', () => ({ goalsAPI: mocks.goals }));

const wrappers = [];
const render = component => {
  const wrapper = mount(component, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: translations },
        }),
      ],
      stubs: { Teleport: true, RouterLink: { template: '<a><slot /></a>' } },
    },
  });
  wrappers.push(wrapper);
  return wrapper;
};

beforeEach(() => {
  mocks.route = reactive({ params: { accountId: '2' }, query: { new: '1' } });
  mocks.contacts.get.mockImplementation(async page => ({
    data: {
      payload: [
        {
          id: page === 1 ? 1 : 94,
          name: page === 1 ? 'Primeiro' : 'Cliente página 2',
        },
      ],
      meta: { count: 94 },
    },
  }));
  mocks.contacts.show.mockImplementation(async id => ({
    data: { payload: { id, name: 'Cliente selecionado' } },
  }));
  mocks.contacts.search.mockResolvedValue({
    data: {
      payload: [{ id: 240, name: 'Cliente distante' }],
      meta: { count: 1 },
    },
  });
  mocks.deals.create.mockResolvedValue({ data: { id: 8 } });
});
afterEach(() => {
  wrappers.splice(0).forEach(w => w.unmount());
  vi.useRealTimers();
});

it('selects and saves a customer beyond the first page in the New Deal modal', async () => {
  const wrapper = render(DealsIndex);
  await flushPromises();
  const next = wrapper
    .findAll('button')
    .find(b => b.text() === translations.CRM.COMMERCIAL.NEXT);
  await next.trigger('click');
  await flushPromises();
  expect(mocks.contacts.get).toHaveBeenCalledWith(2);
  await wrapper
    .findAll('button')
    .find(b => b.text().includes('Cliente página 2'))
    .trigger('click');
  await wrapper
    .find('input[placeholder="Ex.: STIR/SHAKEN"]')
    .setValue('Venda QA');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(mocks.deals.create.mock.calls[0][0].deal.contact_id).toBe(94);
});

it('searches the full customer base in the New Deal modal', async () => {
  const wrapper = render(DealsIndex);
  await flushPromises();
  vi.useFakeTimers();
  await wrapper.find('input[type="search"]').setValue('distante');
  await vi.advanceTimersByTimeAsync(260);
  await flushPromises();
  expect(mocks.contacts.search).toHaveBeenCalledWith('distante', 1);
  await wrapper
    .findAll('button')
    .find(b => b.text().includes('Cliente distante'))
    .trigger('click');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(mocks.deals.create.mock.calls[0][0].deal.contact_id).toBe(240);
});

it('shows quantity goal progress as units with the selected period and criteria', async () => {
  mocks.goals.list.mockResolvedValue({
    data: [
      {
        id: 3,
        name: 'Vendas setembro',
        status: 'active',
        metric: 'quantity',
        period_start: '2026-09-01',
        period_end: '2026-09-30',
      },
    ],
  });
  mocks.goals.dashboard.mockResolvedValue({
    data: {
      metric: 'quantity',
      target_cents: 300,
      realized_cents: 200,
      goals: [
        {
          name: 'Vendas setembro',
          metric: 'quantity',
          calculation_method: 'completed_orders',
          period_start: '2026-09-01',
          period_end: '2026-09-30',
          criteria: { order_statuses: ['completed'] },
        },
      ],
    },
  });
  const wrapper = render(GoalsView);
  await flushPromises();
  expect(mocks.goals.dashboard).toHaveBeenCalledWith({
    goal_id: 3,
    start_date: '2026-09-01',
    end_date: '2026-09-30',
  });
  const card = wrapper
    .findAll('article')
    .find(node => node.text().startsWith('Realizado'));
  expect(card.text()).toContain('200');
  expect(card.text()).not.toContain('R$');
  expect(wrapper.text()).toContain('Pedidos concluídos');
  expect(wrapper.text()).toContain('Concluído');
});
