import { mount, enableAutoUnmount } from '@vue/test-utils';
import { ref } from 'vue';
import Editor from '../Editor.vue';

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({ captainTasksEnabled: ref(false) }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    isEditorHotKeyEnabled: () => false,
    fetchSignatureFlagFromUISettings: () => false,
  }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
  useTrack: vi.fn(),
}));
enableAutoUnmount(afterEach);

it('inserts reviewed Markdown through the real native ProseMirror schema and preserves the existing draft', async () => {
  const wrapper = mount(Editor, {
    props: {
      modelValue: 'Existing draft',
      channelType: 'Channel::WebWidget',
      focusOnMount: false,
    },
  });
  await expect(
    wrapper.vm.insertReviewedCannedResponse('**Reviewed text**')
  ).resolves.toBe(true);
  expect(wrapper.get('.ProseMirror strong').text()).toBe('Reviewed text');
  const content = wrapper.emitted('update:modelValue').at(-1)[0];
  expect(content).toContain('Existing draft');
  expect(content).toContain('**Reviewed text**');
});

it.each([{ disabled: true }, { isPrivate: true }])(
  'refuses reviewed insertion in an unavailable public editor: %j',
  async props => {
    const wrapper = mount(Editor, {
      props: { modelValue: 'Unchanged draft', focusOnMount: false, ...props },
    });
    await expect(
      wrapper.vm.insertReviewedCannedResponse('Forbidden insertion')
    ).resolves.toBe(false);
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    expect(wrapper.get('.ProseMirror').text()).toBe('Unchanged draft');
  }
);
