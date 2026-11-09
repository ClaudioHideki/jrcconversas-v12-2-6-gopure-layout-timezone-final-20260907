import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/en/crm.json';
import CrmLayout from '../CrmLayout.vue';

const mocks = vi.hoisted(() => ({ route: null, store: null }));
vi.mock('vue-router', () => ({ useRoute: () => mocks.route }));
vi.mock('vuex', () => ({ useStore: () => mocks.store }));

describe('CRM module navigation', () => {
  let wrapper;
  beforeEach(() => {
    mocks.route = reactive({
      name: 'crm_dashboard',
      fullPath: '/app/accounts/1/crm/dashboard',
      params: { accountId: '1' },
    });
    mocks.store = reactive({ getters: { getCurrentRole: 'administrator' } });
    wrapper = mount(CrmLayout, {
      attachTo: document.body,
      global: {
        plugins: [
          createI18n({
            legacy: false,
            locale: 'en',
            messages: { en: messages },
          }),
        ],
        stubs: {
          VDropdown: {
            name: 'VDropdown',
            props: ['shown'],
            template: '<div><slot /><slot v-if="shown" name="popper" /></div>',
          },
          RouterLink: {
            props: ['to'],
            template: '<a :href="to.name" @click.prevent><slot /></a>',
          },
          RouterView: true,
        },
      },
    });
  });
  afterEach(() => {
    const element = wrapper.element;
    wrapper.unmount();
    element.remove();
  });

  it('keeps five primary links and highlights the group of the current nested destination', async () => {
    expect(
      wrapper.findAll('nav > a').map(link => link.attributes('href'))
    ).toEqual([
      'crm_dashboard',
      'crm_indicators',
      'crm_leads',
      'crm_deals',
      'crm_funnel',
    ]);
    expect(wrapper.findAll('nav ul')).toHaveLength(0);
    await wrapper.get('[data-crm-group="commercial"]').trigger('click');
    expect(
      wrapper
        .findAll('#crm-nav-commercial a')
        .map(link => link.attributes('href'))
    ).toEqual([
      'crm_wallet',
      'crm_products',
      'crm_proposals',
      'crm_orders',
      'crm_contracts',
    ]);
    mocks.route.name = 'crm_orders';
    mocks.route.fullPath = '/app/accounts/1/crm/orders';
    await flushPromises();
    expect(
      wrapper.get('[data-crm-group="commercial"]').attributes('data-active')
    ).toBe('true');
    expect(wrapper.findAll('nav ul')).toHaveLength(0);
    await wrapper.get('[data-crm-group="commercial"]').trigger('click');
    expect(wrapper.get('[aria-current="page"]').attributes('href')).toBe(
      'crm_orders'
    );
    await wrapper
      .get('#crm-nav-commercial a[href="crm_orders"]')
      .trigger('click');
    expect(wrapper.findAll('nav ul')).toHaveLength(0);
  });

  it('opens one group at a time and returns focus to the trigger on Escape', async () => {
    const commercial = wrapper.get('[data-crm-group="commercial"]');
    const planning = wrapper.get('[data-crm-group="planning"]');
    await commercial.trigger('click');
    await planning.trigger('keydown', { key: 'ArrowDown' });
    expect(commercial.attributes('aria-expanded')).toBe('false');
    expect(planning.attributes('aria-expanded')).toBe('true');
    // A delayed hide from the previous dropdown must not close the new group.
    wrapper
      .findAllComponents({ name: 'VDropdown' })[0]
      ?.vm.$emit('update:shown', false);
    await flushPromises();
    expect(planning.attributes('aria-expanded')).toBe('true');
    expect(wrapper.findAll('#crm-nav-planning a')).toHaveLength(4);
    await wrapper
      .get('#crm-nav-planning')
      .trigger('keydown', { key: 'Escape' });
    expect(planning.attributes('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(planning.element);
  });

  it('preserves Backoffice access and hides administrator-only links from agents', async () => {
    const management = wrapper.get('[data-crm-group="management"]');
    await management.trigger('click');
    expect(
      wrapper
        .findAll('#crm-nav-management a')
        .map(link => link.attributes('href'))
    ).toEqual(['crm_backoffice', 'crm_management', 'crm_settings']);
    mocks.store.getters.getCurrentRole = 'agent';
    await flushPromises();
    expect(
      wrapper
        .findAll('#crm-nav-management a')
        .map(link => link.attributes('href'))
    ).toEqual(['crm_backoffice']);
  });
});
