import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import CannedFileInput from '../CannedFileInput.vue';
import API from 'dashboard/api/cannedResponse';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/cannedResponse', () => ({ default: { file: vi.fn() } }));
enableAutoUnmount(afterEach);
beforeEach(() => {
  URL.createObjectURL = vi.fn(() => 'blob:synthetic-file');
  URL.revokeObjectURL = vi.fn();
  API.file.mockResolvedValue({ data: new Blob(['synthetic']) });
});
const render = (props = {}) => mount(CannedFileInput, { props });

it('previews an existing image through its account-scoped revision-checked endpoint', async () => {
  const initialFile = {
    id: 4,
    filename: 'old.png',
    content_type: 'image/png',
    revision: 'review-1',
  };
  const wrapper = render({ initialFile, responseId: 3, accountId: 7 });
  await flushPromises();
  expect(API.file).toHaveBeenCalledWith(3, 7, {
    revision: 'review-1',
    attachment_id: 4,
  });
  expect(wrapper.get('img').attributes('src')).toBe('blob:synthetic-file');
});

it('preserves a selected replacement and emits explicit removal without uploading an orphan blob', async () => {
  const wrapper = render();
  const file = new File(['synthetic-pdf'], 'replacement.pdf', {
    type: 'application/pdf',
  });
  const input = wrapper.get('input[type="file"]');
  Object.defineProperty(input.element, 'files', {
    configurable: true,
    value: [file],
  });
  await input.trigger('change');
  expect(wrapper.emitted('change')[0]).toEqual([{ file, remove_file: false }]);
  expect(wrapper.text()).toContain('replacement.pdf');
  expect(API.file).not.toHaveBeenCalled();
  await wrapper
    .findAll('button')
    .find(button => button.text().includes('QUICK.REMOVE'))
    .trigger('click');
  expect(wrapper.emitted('change')[1]).toEqual([
    { file: null, remove_file: true },
  ]);
  expect(wrapper.text()).not.toContain('replacement.pdf');
});

it('does not display an attachment returned after the account or model changes', async () => {
  let complete;
  API.file.mockImplementationOnce(
    () =>
      new Promise(resolve => {
        complete = resolve;
      })
  );
  const wrapper = render({
    initialFile: {
      id: 4,
      filename: 'old.png',
      content_type: 'image/png',
      revision: 'r1',
    },
    responseId: 3,
    accountId: 7,
  });
  await wrapper.setProps({ accountId: 8, initialFile: null });
  complete({ data: new Blob(['old account']) });
  await flushPromises();
  expect(wrapper.find('img').exists()).toBe(false);
  expect(URL.createObjectURL).not.toHaveBeenCalled();
});

it('keeps the existing file reference and shows a useful error on download failure', async () => {
  API.file.mockRejectedValue(new Error('Forbidden'));
  const wrapper = render({
    initialFile: {
      id: 4,
      filename: 'old.png',
      content_type: 'image/png',
      revision: 'r1',
    },
    responseId: 3,
    accountId: 7,
  });
  await flushPromises();
  expect(wrapper.get('[role="alert"]').text()).toBe('CANNED_MGMT.QUICK.ERROR');
  expect(wrapper.text()).toContain('old.png');
  expect(wrapper.emitted('change')).toBeUndefined();
});
