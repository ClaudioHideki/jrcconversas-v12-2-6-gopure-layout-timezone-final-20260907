import { reactive, ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import ComposeNewConversationForm from '../components/ComposeNewConversationForm.vue';

vi.mock('dashboard/composables/useCopilotReply', () => ({
  useCopilotReply: () => ({ isActive: ref(false), reset: vi.fn() }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

let wrapper;
const formState = () =>
  reactive({
    message: 'Synthetic proposal link',
    subject: 'Synthetic subject',
    ccEmails: '',
    bccEmails: '',
    attachedFiles: [],
    attachPdf: true,
  });
const mountForm = (channelType = 'Channel::Api', props = {}) => {
  const state = formState();
  wrapper = shallowMount(ComposeNewConversationForm, {
    props: {
      proposalMode: true,
      proposalUrl: 'https://example.test/proposal',
      formState: state,
      currentUser: { id: 2 },
      selectedContact: {
        id: 3,
        name: 'Synthetic contact',
        contactInboxes: [{ id: 4, name: 'Synthetic inbox', channelType }],
      },
      targetInbox: { id: 4, channelType },
      contactConversationsUiFlags: { isCreating: false },
      contactsUiFlags: { isFetchingInboxes: false },
      ...props,
    },
  });
  return state;
};
afterEach(() => wrapper?.unmount());

it('sends the link and PDF choice without leaking an old email subject into WhatsApp', async () => {
  const state = mountForm();
  await wrapper.get('input[type="checkbox"]').setValue(false);
  const send = wrapper
    .findAll('button')
    .find(item => item.text() === 'Send proposal');
  await send.trigger('click');
  await flushPromises();
  const payload = wrapper.emitted('createConversation')[0][0].payload;
  expect(payload).toMatchObject({ contactId: 3, inboxId: 4, attachPdf: false });
  expect(payload).not.toHaveProperty('mailSubject');
  expect(state.message).toBe('Synthetic proposal link');
});

it('requires an email subject and uses the compact subject input', async () => {
  const state = mountForm('Channel::Email');
  await wrapper.get('#proposal-recipient-subject').setValue('');
  const send = wrapper
    .findAll('button')
    .find(item => item.text() === 'Send proposal');
  await send.trigger('click');
  await flushPromises();
  expect(wrapper.emitted('createConversation')).toBeUndefined();
  await wrapper.get('#proposal-recipient-subject').setValue('Reviewed subject');
  await send.trigger('click');
  await flushPromises();
  expect(wrapper.emitted('createConversation')[0][0].payload.mailSubject).toBe(
    'Reviewed subject'
  );
  expect(state.message).toBe('Synthetic proposal link');
});

it('disables edits and send while a proposal delivery is in progress', () => {
  mountForm('Channel::Api', {
    contactConversationsUiFlags: { isCreating: true },
  });
  expect(wrapper.get('textarea').attributes('disabled')).toBeDefined();
  expect(
    wrapper.get('input[type="checkbox"]').attributes('disabled')
  ).toBeDefined();
  expect(
    wrapper
      .findAll('button')
      .find(item => item.text() === 'Sending…')
      .attributes('disabled')
  ).toBeDefined();
});
