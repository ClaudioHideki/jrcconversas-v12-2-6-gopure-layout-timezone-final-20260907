import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReplyBottomPanel from '../ReplyBottomPanel.vue';

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    setSignatureFlagForInbox: vi.fn(),
    fetchSignatureFlagFromUISettings: vi.fn(),
  }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('activestorage', () => ({ start: vi.fn() }));
const Button = {
  props: ['icon', 'disabled', 'label'],
  emits: ['click'],
  template:
    '<button :disabled="disabled" :data-icon="icon" @click="$emit(\'click\', $event)">{{ label }}<slot /></button>',
};
let wrappers;
const render = (props = {}) => {
  const store = createStore({
    getters: {
      getCurrentAccountId: () => 1,
      'accounts/isFeatureEnabledonAccount': () => () => true,
      'integrations/getUIFlags': () => ({}),
    },
  });
  const wrapper = mount(ReplyBottomPanel, {
    attachTo: document.body,
    props: {
      conversationId: 947,
      inbox: { channel_type: 'Channel::Api', medium: 'whatsapp' },
      showFileUpload: true,
      showAudioRecorder: true,
      ...props,
    },
    global: {
      plugins: [store],
      stubs: { NextButton: Button, VideoCallButton: true },
    },
  });
  wrappers.push(wrapper);
  return wrapper;
};
beforeEach(() => {
  wrappers = [];
  vi.stubGlobal('MediaRecorder', class {});
  Object.defineProperty(navigator, 'mediaDevices', {
    configurable: true,
    value: { getUserMedia: vi.fn() },
  });
});
afterEach(() => {
  wrappers.forEach(wrapper => wrapper.unmount());
  vi.unstubAllGlobals();
});

it('opens the input belonging to the clicked toolbar when two composers are mounted', async () => {
  const first = render();
  const second = render({ conversationId: 948 });
  const firstInput = first.get('input[type="file"]');
  const secondInput = second.get('input[type="file"]');
  expect(firstInput.attributes('id')).not.toBe(secondInput.attributes('id'));
  const clickFirst = vi.spyOn(firstInput.element, 'click');
  const clickSecond = vi.spyOn(secondInput.element, 'click');
  await second.get('[data-icon="i-ph-paperclip"]').trigger('click');
  expect(clickFirst).not.toHaveBeenCalled();
  expect(clickSecond).toHaveBeenCalledOnce();
});

it.each([
  ['Channel::Api', 'whatsapp'],
  ['Channel::Whatsapp', 'whatsapp'],
  ['Channel::Email', 'email'],
  ['Channel::WebWidget', 'web'],
  ['Channel::Sms', 'sms'],
])(
  'connects native emoji, upload and send actions for %s',
  async (channel_type, medium) => {
    const toggleEmojiPicker = vi.fn();
    const onFileUpload = vi.fn();
    const onSend = vi.fn();
    const wrapper = render({
      inbox: { channel_type, medium },
      toggleEmojiPicker,
      onFileUpload,
      onSend,
      sendButtonText: 'Enviar',
    });
    await wrapper.get('[data-icon="i-ph-smiley-sticker"]').trigger('click');
    expect(toggleEmojiPicker).toHaveBeenCalledOnce();
    const input = wrapper.get('input[type="file"]');
    const file = new File(['synthetic'], 'imagem.png', { type: 'image/png' });
    Object.defineProperty(input.element, 'files', {
      configurable: true,
      value: [file],
    });
    await input.trigger('change');
    await flushPromises();
    expect(onFileUpload).toHaveBeenCalled();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Enviar')
      .trigger('click');
    expect(onSend).toHaveBeenCalledOnce();
  }
);

it('honors disabled editors and unavailable attachments without opening another picker or sending', async () => {
  const onSend = vi.fn();
  const wrapper = render({
    isEditorDisabled: true,
    isSendDisabled: true,
    onSend,
    sendButtonText: 'Enviar',
  });
  expect(wrapper.find('[data-icon="i-ph-paperclip"]').exists()).toBe(false);
  expect(wrapper.find('[data-icon="i-ph-microphone"]').exists()).toBe(false);
  expect(wrapper.find('[data-icon="i-ph-smiley-sticker"]').exists()).toBe(
    false
  );
  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Enviar')
    .trigger('click');
  expect(onSend).not.toHaveBeenCalled();
});

it('connects recording, stopping and playback and hides unsupported recording on LINE', async () => {
  const toggleAudioRecorder = vi.fn();
  const toggleAudioRecorderPlayPause = vi.fn();
  const wrapper = render({ toggleAudioRecorder, toggleAudioRecorderPlayPause });
  await wrapper.get('[data-icon="i-ph-microphone"]').trigger('click');
  expect(toggleAudioRecorder).toHaveBeenCalledOnce();
  await wrapper.setProps({
    isRecordingAudio: true,
    recordingAudioState: 'stopped',
  });
  await wrapper.get('[data-icon="i-ph-play"]').trigger('click');
  expect(toggleAudioRecorderPlayPause).toHaveBeenCalledOnce();
  await wrapper.setProps({ inbox: { channel_type: 'Channel::Line' } });
  expect(wrapper.find('[data-icon="i-ph-microphone-slash"]').exists()).toBe(
    false
  );
});

it('disables microphone recording with an explanation when the browser cannot record', () => {
  vi.stubGlobal('MediaRecorder', undefined);
  const wrapper = render();
  const microphone = wrapper.get('[data-icon="i-ph-microphone"]');
  expect(microphone.attributes('disabled')).toBeDefined();
  expect(microphone.attributes('title')).toContain('navegador');
});
