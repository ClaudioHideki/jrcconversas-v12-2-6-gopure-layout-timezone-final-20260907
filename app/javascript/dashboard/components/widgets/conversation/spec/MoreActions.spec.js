import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import MoreActions from '../MoreActions.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('../EmailTranscriptModal.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../../../buttons/ResolveAction.vue', () => ({
  default: { template: '<div />' },
}));

const Button = { props: ['label'], template: '<button>{{ label }}</button>' };
const Menu = {
  props: ['menuItems'],
  emits: ['action'],
  template:
    '<div data-test-menu><button v-for="item in menuItems" :key="item.value" @click="$emit(\'action\', item)">{{ item.label }}</button></div>',
};

let wrapper;
let host;
let store;
let assign;
beforeEach(() => {
  vi.stubGlobal(
    'matchMedia',
    vi.fn(() => ({
      matches: false,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    }))
  );
  assign = vi.fn();
  store = createStore({
    state: { chat: { id: 650, inbox_id: 4, status: 'open' } },
    getters: {
      getSelectedChat: state => state.chat,
      'inboxAssignableAgents/getAssignableAgents': () => () => [
        { id: 9, name: 'Agente de teste' },
      ],
      'accounts/isRTL': () => false,
    },
    actions: {
      'inboxAssignableAgents/fetch': vi.fn(),
      assignAgent: assign,
      muteConversation: vi.fn(),
    },
  });
  host = document.createElement('header');
  host.style.overflow = 'auto';
  host.style.height = '56px';
  document.body.append(host);
  wrapper = mount(MoreActions, {
    attachTo: host,
    global: {
      plugins: [
        store,
        createI18n({
          legacy: false,
          locale: 'en',
          messages: { en: {} },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: { ButtonV4: Button, DropdownMenu: Menu },
      directives: { tooltip: {} },
    },
  });
});
afterEach(() => {
  wrapper.unmount();
  host.remove();
  vi.unstubAllGlobals();
});

it('opens assignment outside the clipped header and dispatches the selected agent', async () => {
  await wrapper
    .findAll('button')
    .find(b => b.text() === 'Atribuir')
    .trigger('click');
  await flushPromises();
  const menu = document.querySelector('[data-test-menu]');
  expect(menu).not.toBeNull();
  expect(host.contains(menu)).toBe(false);
  menu.querySelector('button').click();
  await flushPromises();
  expect(assign).toHaveBeenCalledWith(expect.anything(), {
    conversationId: 650,
    agentId: 9,
  });
  expect(document.querySelector('[data-test-menu]')).toBeNull();
});
it('opens more actions outside the clipped header and closes on conversation change', async () => {
  await wrapper
    .find('[aria-label="CONVERSATION.HEADER.MORE_ACTIONS"]')
    .trigger('click');
  await flushPromises();
  const menu = document.querySelector('[data-test-menu]');
  expect(menu).not.toBeNull();
  expect(host.contains(menu)).toBe(false);
  store.state.chat = { id: 651, inbox_id: 4, status: 'open' };
  await flushPromises();
  expect(document.querySelector('[data-test-menu]')).toBeNull();
});
