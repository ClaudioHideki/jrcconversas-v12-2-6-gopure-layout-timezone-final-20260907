import { mount, shallowMount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import CommercialMetricFilters from '../CommercialMetricFilters.vue';
import CrmDashboardView from '../../../views/dashboard/CrmDashboardView.vue';
import KanbanColumn from '../../kanban/KanbanColumn.vue';
import CrmValueDisplay from '../CrmValueDisplay.vue';

it('renders zero expected revenue for a stage with zero probability', () => {
  const wrapper = shallowMount(KanbanColumn, {
    props: {
      stage: { id: 1, name: 'Etapa', probability: 0 },
      deals: [{ id: 1, value_cents: 10_000 }],
    },
  });
  expect(
    wrapper
      .findAllComponents(CrmValueDisplay)
      .map(component => component.props('cents'))
  ).toEqual([10_000, 0]);
  wrapper.unmount();
});

it('keeps a legitimate zero open pipeline and carries filters to the board', async () => {
  const store = createStore({
    getters: {
      'jrcCrm/dashboard/metrics': () => ({
        pipeline_value_cents: 0,
        open_deals_count: 0,
        closed_won_count: 3,
        won_revenue_cents: 1302545,
        funnel_stages: [
          {
            id: 1,
            name: 'Ganho',
            pipeline_name: 'GoPure QA',
            deals_count: 3,
            value_cents: 1302545,
          },
        ],
      }),
      'jrcCrm/dashboard/isLoading': () => false,
    },
  });
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'crm_dashboard', component: CrmDashboardView },
      {
        path: '/funnel',
        name: 'crm_funnel',
        component: { template: '<div />' },
      },
    ],
  });
  await router.push({
    path: '/',
    query: { pipeline_id: '9', start_date: '2026-11-01' },
  });
  await router.isReady();
  const wrapper = shallowMount(CrmDashboardView, {
    global: { plugins: [store, router] },
  });
  const pipelineCard = wrapper
    .findAll('article')
    .find(item => item.text().includes('Pipeline aberto'));
  expect(pipelineCard.text().replaceAll('\u00a0', ' ')).toContain('R$ 0,00');
  expect(wrapper.text()).toContain('13.025,45');
  expect(wrapper.text()).toContain('GoPure QA');
  const links = wrapper
    .findAllComponents({ name: 'RouterLink' })
    .filter(link => link.props('to').name === 'crm_funnel');
  expect(links.length).toBe(2);
  links.forEach(link =>
    expect(link.props('to')).toMatchObject({
      name: 'crm_funnel',
      query: { pipeline_id: '9', start_date: '2026-11-01' },
    })
  );
  wrapper.unmount();
});

it.each(['administrator', 'agent'])(
  'provides creation dates and respects the %s owner boundary in the controls',
  async role => {
    const store = createStore({
      getters: {
        getCurrentRole: () => role,
        'jrcCrm/pipelines/allPipelines': () => [{ id: 7, name: 'Comercial' }],
        'agents/getAgents': () => [{ id: 25, name: 'Agente' }],
      },
    });
    store.dispatch = vi.fn().mockResolvedValue();
    const wrapper = mount(CommercialMetricFilters, {
      global: { plugins: [store] },
    });
    await flushPromises();
    expect(wrapper.emitted('change')[0][0]).toEqual({
      period: 'all',
      owner_id: undefined,
      pipeline_id: undefined,
    });
    expect(wrapper.findAll('select')).toHaveLength(
      role === 'administrator' ? 3 : 2
    );
    const selects = wrapper.findAll('select');
    if (role === 'administrator') await selects[0].setValue('25');
    await selects.at(-2).setValue('7');
    await selects.at(-1).setValue('custom');
    await wrapper.findAll('input')[0].setValue('2026-10-01');
    await wrapper.findAll('input')[1].setValue('2026-11-04');
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('change').at(-1)[0]).toEqual({
      period: 'custom',
      pipeline_id: 7,
      owner_id: role === 'administrator' ? 25 : undefined,
      start_date: '2026-10-01',
      end_date: '2026-11-04',
    });
    wrapper.unmount();
  }
);

it('initializes the summary with the filters carried from the board', async () => {
  const store = createStore({
    getters: {
      getCurrentRole: () => 'administrator',
      'jrcCrm/pipelines/allPipelines': () => [{ id: 9, name: 'QA' }],
      'agents/getAgents': () => [{ id: 2, name: 'QA' }],
    },
  });
  store.dispatch = vi.fn().mockResolvedValue();
  const wrapper = mount(CommercialMetricFilters, {
    props: {
      initialFilters: {
        pipeline_id: '9',
        owner_id: '2',
        period: 'custom',
        start_date: '2026-11-01',
        end_date: '2026-11-06',
      },
    },
    global: { plugins: [store] },
  });
  await flushPromises();
  expect(wrapper.emitted('change')[0][0]).toMatchObject({
    pipeline_id: '9',
    owner_id: '2',
    start_date: '2026-11-01',
    end_date: '2026-11-06',
  });
  wrapper.unmount();
});
