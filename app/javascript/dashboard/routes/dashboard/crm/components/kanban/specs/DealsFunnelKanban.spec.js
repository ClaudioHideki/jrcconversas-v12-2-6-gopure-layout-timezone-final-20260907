import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import Funnel from '../DealsFunnelKanban.vue';
import deals from 'dashboard/store/crm/modules/deals';
import pipelines from 'dashboard/store/crm/modules/pipelines';
import {
  dealsAPI,
  stagesAPI,
  pipelinesAPI,
  lostReasonsAPI,
  leadsAPI,
} from 'dashboard/api/crm';

vi.mock('dashboard/api/crm', () => ({
  dealsAPI: { list: vi.fn(), moveStage: vi.fn() },
  stagesAPI: { list: vi.fn() },
  pipelinesAPI: { list: vi.fn() },
  lostReasonsAPI: { list: vi.fn() },
  leadsAPI: { list: vi.fn() },
}));
let wrapper;
let store;
let router;
beforeEach(() => {
  leadsAPI.list.mockResolvedValue({ data: [] });
  pipelinesAPI.list.mockResolvedValue({ data: [{ id: 1, name: 'Comercial' }] });
  stagesAPI.list.mockResolvedValue({
    data: [
      { id: 10, name: 'Entrada' },
      { id: 11, name: 'Proposta' },
    ],
  });
  dealsAPI.list.mockResolvedValue({ data: [] });
  store = createStore({
    getters: { getCurrentRole: () => 'administrator' },
    modules: {
      agents: {
        namespaced: true,
        state: { records: [{ id: 7, name: 'Responsável' }] },
        actions: { get: vi.fn() },
      },
      jrcCrm: {
        namespaced: true,
        modules: {
          deals: { ...deals, state: structuredClone(deals.state) },
          pipelines: { ...pipelines, state: structuredClone(pipelines.state) },
        },
      },
    },
  });
  router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: Funnel },
      { path: '/leads', name: 'crm_leads', component: { template: '<div />' } },
      { path: '/deals', name: 'crm_deals', component: { template: '<div />' } },
      {
        path: '/summary',
        name: 'crm_dashboard',
        component: { template: '<div />' },
      },
    ],
  });
});
afterEach(() => wrapper?.unmount());
const render = async () => {
  await router.push('/');
  await router.isReady();
  wrapper = mount(Funnel, { global: { plugins: [store, router] } });
  await flushPromises();
};

describe('funnel rendered journeys', () => {
  it('shows qualified leads separately and never routes them through deal drag/drop', async () => {
    leadsAPI.list.mockResolvedValue({
      data: [
        { id: 99, name: 'Qualified synthetic person', status: 'qualified' },
      ],
    });
    await render();
    expect(wrapper.text()).toContain('Qualified synthetic person');
    const link = wrapper.find('a[href="/leads?leadId=99"]');
    expect(link.exists()).toBe(true);
    expect(link.attributes('draggable')).toBeUndefined();
    expect(dealsAPI.moveStage).not.toHaveBeenCalled();
    await link.trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.query.leadId).toBe('99');
  });
  it('renders empty stages, explanatory empty state and working New opportunity destination', async () => {
    await render();
    expect(wrapper.text()).toContain('Entrada');
    expect(wrapper.text()).toContain('Nenhuma oportunidade encontrada');
    const link = wrapper
      .findAll('a')
      .find(a => a.text().includes('Nova oportunidade'));
    await link.trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.name).toBe('crm_deals');
    expect(router.currentRoute.value.query.new).toBe('1');
  });
  it('renders cards and real filters, then clears filters', async () => {
    dealsAPI.list.mockResolvedValue({
      data: [
        {
          id: 1,
          title: 'Venda teste',
          stage_id: 10,
          value_cents: 10000,
          owner: { name: 'Teste' },
        },
      ],
    });
    await render();
    expect(wrapper.text()).toContain('Venda teste');
    await wrapper.find('input[type=text]').setValue('Venda');
    await flushPromises();
    expect(dealsAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ search: 'Venda' })
    );
    await wrapper.findAll('select')[1].setValue('7');
    await flushPromises();
    expect(dealsAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ owner_id: 7 })
    );
    await wrapper
      .findAll('button')
      .find(b => b.text() === 'Limpar Filtros')
      .trigger('click');
    await flushPromises();
    expect(dealsAPI.list).toHaveBeenLastCalledWith(
      expect.objectContaining({ search: '', owner_id: undefined })
    );
  });
  it('does not let an unrelated lost-reasons endpoint prevent board loading', async () => {
    lostReasonsAPI.list.mockRejectedValue(new Error('Unavailable'));
    await render();
    expect(wrapper.text()).toContain('Entrada');
    expect(lostReasonsAPI.list).not.toHaveBeenCalled();
  });
  it('shows an initialization error and retries instead of leaving a blank board', async () => {
    pipelinesAPI.list.mockRejectedValueOnce({ response: { status: 403 } });
    await render();
    expect(wrapper.find('[role=alert]').text()).toContain(
      'Não foi possível carregar os funis.'
    );
    await wrapper
      .findAll('button')
      .find(b => b.text() === 'Tentar novamente')
      .trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Entrada');
  });
  it.each([{ rows: [] }, { rows: [{ id: 1, name: 'Sem etapas' }] }])(
    'explains missing pipelines or stages',
    async ({ rows }) => {
      pipelinesAPI.list.mockResolvedValue({ data: rows });
      stagesAPI.list.mockResolvedValue({ data: [] });
      await render();
      expect(wrapper.find('[role=status]').text()).toMatch(
        /Nenhum funil|não tem etapas/
      );
    }
  );
  it('persists a drag/drop through the API and reloads the board', async () => {
    const record = {
      id: 1,
      title: 'Mover teste',
      stage_id: 10,
      value_cents: 10000,
      owner: { name: 'Teste' },
    };
    dealsAPI.list.mockImplementation(async () => ({ data: [{ ...record }] }));
    dealsAPI.moveStage.mockImplementation(async (_id, { stage_id: id }) => {
      record.stage_id = id;
    });
    await render();
    const columns = wrapper.findAllComponents({ name: 'KanbanColumn' });
    columns[0].vm.$emit('dragStart', { dataTransfer: null }, record);
    columns[1].vm.$emit('drop', { preventDefault: vi.fn() });
    await flushPromises();
    expect(dealsAPI.moveStage).toHaveBeenCalledWith(1, {
      stage_id: 11,
      lost_reason_id: null,
    });
    expect(columns[1].text()).toContain('Mover teste');
    expect(columns[0].text()).not.toContain('Mover teste');
  });
  it('restores the previous stage and explains a rejected move', async () => {
    const record = {
      id: 1,
      title: 'Mover teste',
      stage_id: 10,
      owner: { name: 'Teste' },
    };
    dealsAPI.list.mockResolvedValue({ data: [record] });
    dealsAPI.moveStage.mockRejectedValue({ response: { status: 403 } });
    await render();
    const columns = wrapper.findAllComponents({ name: 'KanbanColumn' });
    columns[0].vm.$emit('dragStart', { dataTransfer: null }, record);
    columns[1].vm.$emit('drop', { preventDefault: vi.fn() });
    await flushPromises();
    expect(columns[0].text()).toContain('Mover teste');
    expect(wrapper.find('[role=alert]').text()).toContain(
      'etapa anterior foi mantida'
    );
  });
});

it('defaults to all pipelines, carries filters and keeps qualified leads after clearing', async () => {
  leadsAPI.list.mockImplementation(async ({ status }) => ({
    data: status ? [] : [{ id: 99, name: 'Qualified QA', status: 'qualified' }],
  }));
  pipelinesAPI.list.mockResolvedValue({
    data: [
      { id: 1, name: 'GoPure' },
      { id: 2, name: 'Legacy' },
    ],
  });
  stagesAPI.list.mockImplementation(async ({ pipeline_id }) => ({
    data: [
      {
        id: pipeline_id * 10,
        name: pipeline_id === 1 ? 'Novo Lead' : 'Lead',
        pipeline_id,
        pipeline_name: pipeline_id === 1 ? 'GoPure' : 'Legacy',
      },
    ],
  }));
  await render();
  expect(
    wrapper.findAll('select')[0].element.selectedOptions[0].textContent
  ).toBe('Todos os Funis');
  expect(
    wrapper.findAll('select')[1].element.selectedOptions[0].textContent
  ).toBe('Todos os Responsáveis');
  expect(stagesAPI.list).toHaveBeenCalledWith({ pipeline_id: 1 });
  expect(stagesAPI.list).toHaveBeenCalledWith({ pipeline_id: 2 });
  expect(
    wrapper
      .findAllComponents({ name: 'KanbanColumn' })
      .map(c => c.props('stage').name)
  ).toEqual(['Novo Lead', 'Lead']);
  expect(wrapper.text()).toContain('Legacy');
  await wrapper.findAll('select')[0].setValue('1');
  await wrapper.findAll('input[type=date]')[0].setValue('2026-11-01');
  await flushPromises();
  const summary = wrapper
    .findAll('a')
    .find(a => a.text().includes('Ver Visão Geral'));
  expect(summary.attributes('href')).toContain('pipeline_id=1');
  expect(summary.attributes('href')).toContain('start_date=2026-11-01');
  await wrapper
    .findAll('button')
    .find(b => b.text() === 'Limpar Filtros')
    .trigger('click');
  await flushPromises();
  expect(dealsAPI.list).toHaveBeenLastCalledWith(
    expect.objectContaining({ pipeline_id: undefined, start_date: undefined })
  );
  expect(leadsAPI.list.mock.calls.at(-1)[0]).not.toHaveProperty('status');
  expect(wrapper.text()).toContain('Qualified QA');
});

it('opens the board with the same summary filters without hiding qualified pre-sale leads', async () => {
  leadsAPI.list.mockResolvedValue({
    data: [{ id: 99, name: 'Qualified QA', status: 'qualified' }],
  });
  await router.push({
    path: '/',
    query: { pipeline_id: '1', owner_id: '7', start_date: '2026-11-01' },
  });
  await router.isReady();
  wrapper = mount(Funnel, { global: { plugins: [store, router] } });
  await flushPromises();
  expect(dealsAPI.list).toHaveBeenCalledWith(
    expect.objectContaining({
      pipeline_id: '1',
      owner_id: '7',
      start_date: '2026-11-01',
    })
  );
  expect(leadsAPI.list).toHaveBeenCalledWith(
    expect.objectContaining({
      owner_id: '7',
      start_date: '2026-11-01',
      funnel: true,
      period: 'custom',
    })
  );
  expect(leadsAPI.list.mock.calls.at(-1)[0]).not.toHaveProperty('pipeline_id');
  expect(wrapper.text()).toContain('Qualified QA');
});

it('does not forward an owner from a shared administrator link when the viewer is an agent', async () => {
  store.hotUpdate({ getters: { getCurrentRole: () => 'agent' } });
  await router.push({ path: '/', query: { owner_id: '7' } });
  await router.isReady();
  wrapper = mount(Funnel, { global: { plugins: [store, router] } });
  await flushPromises();
  expect(dealsAPI.list).toHaveBeenLastCalledWith(
    expect.objectContaining({ owner_id: undefined })
  );
  expect(leadsAPI.list.mock.calls.at(-1)[0].owner_id).toBeFalsy();
});
