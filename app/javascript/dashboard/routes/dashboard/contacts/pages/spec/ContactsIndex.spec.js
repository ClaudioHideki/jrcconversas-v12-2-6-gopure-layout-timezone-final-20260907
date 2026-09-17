import { shallowMount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import ContactsIndex from '../ContactsIndex.vue';

vi.mock('vue-router', () => ({ useRoute: vi.fn(), useRouter: vi.fn() }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));
vi.mock('@chatwoot/utils', async importOriginal => ({
  ...(await importOriginal()),
  debounce: fn => fn,
}));

describe('Relationship center navigation', () => {
  let store;
  let route;
  const mountPage = () =>
    shallowMount(ContactsIndex, {
      global: {
        plugins: [
          {
            install(app) {
              app.config.globalProperties.$store = store;
            },
          },
        ],
      },
    });
  beforeEach(() => {
    route = reactive({
      name: 'contacts_dashboard_index',
      params: { accountId: '1' },
      query: { page: '1' },
    });
    useRoute.mockReturnValue(route);
    useRouter.mockReturnValue({ replace: vi.fn(), push: vi.fn() });
    store = {
      dispatch: vi.fn().mockResolvedValue(undefined),
      getters: reactive({
        'contacts/getContactsList': [{ id: 141, name: 'Thiago' }],
        'contacts/getMeta': { count: 94, currentPage: 1 },
        'contacts/getUIFlags': { isFetching: false },
        'customViews/getUIFlags': { isFetching: false },
        'customViews/getContactCustomViews': [],
        'contacts/getAppliedContactFilters': [],
        getCurrentAccount: { permissions: ['jrc_crm'] },
        'accounts/isFeatureEnabledonAccount': () => true,
      }),
    };
  });

  it('enables Next for 94 contacts without has_more and navigates in both directions', async () => {
    const wrapper = mountPage();
    await flushPromises();
    const button = label =>
      wrapper.findAll('button').find(item => item.text() === label);
    expect(button('Anterior').element.disabled).toBe(true);
    expect(button('Próxima').element.disabled).toBe(false);
    await button('Próxima').trigger('click');
    await flushPromises();
    expect(store.dispatch).toHaveBeenCalledWith(
      'contacts/get',
      expect.objectContaining({ page: 2 })
    );
    store.getters['contacts/getMeta'].currentPage = 7;
    await flushPromises();
    expect(button('Próxima').element.disabled).toBe(true);
    await button('Anterior').trigger('click');
    await flushPromises();
    expect(store.dispatch).toHaveBeenCalledWith(
      'contacts/get',
      expect.objectContaining({ page: 6 })
    );
  });

  it('renders search continuation and requests the next results with append enabled', async () => {
    route.query.search = 'Thiago';
    store.getters['contacts/getMeta'].hasMore = true;
    const wrapper = mountPage();
    await flushPromises();
    const more = wrapper.getComponent({ name: 'ContactsLoadMore' });
    more.vm.$emit('loadMore');
    await flushPromises();
    expect(store.dispatch).toHaveBeenCalledWith(
      'contacts/search',
      expect.objectContaining({ page: 2, search: 'Thiago', append: true })
    );
    store.getters['contacts/getMeta'].hasMore = false;
    await flushPromises();
    expect(wrapper.findComponent({ name: 'ContactsLoadMore' }).exists()).toBe(
      false
    );
  });

  it('shows both lead entry points only when the account and user have CRM access', async () => {
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('Novo Lead');
    expect(wrapper.findComponent({ name: 'ContactLeadAction' }).exists()).toBe(
      true
    );
    store.getters.getCurrentAccount.permissions = [];
    await flushPromises();
    expect(wrapper.text()).not.toContain('Novo Lead');
    expect(wrapper.findComponent({ name: 'ContactLeadAction' }).exists()).toBe(
      false
    );
    store.getters.getCurrentAccount.permissions = ['jrc_crm'];
    store.getters['accounts/isFeatureEnabledonAccount'] = () => false;
    await flushPromises();
    expect(wrapper.text()).not.toContain('Novo Lead');
  });
});
