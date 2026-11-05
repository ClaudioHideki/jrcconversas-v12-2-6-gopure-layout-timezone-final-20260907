import { mount, flushPromises } from '@vue/test-utils';
import WaveSurfer from 'wavesurfer.js';
import { convertAudio } from '../utils/audioConversionUtils';
import AudioRecorder from '../AudioRecorder.vue';

vi.mock('wavesurfer.js', () => ({ default: { create: vi.fn() } }));
vi.mock('wavesurfer.js/dist/plugins/record.js', () => ({
  default: { create: vi.fn() },
}));
vi.mock('../utils/audioConversionUtils', () => ({ convertAudio: vi.fn() }));
let wrapper;
let recording;
let wave;
let events;
beforeEach(() => {
  vi.stubGlobal('MediaRecorder', { isTypeSupported: () => true });
  Object.defineProperty(navigator, 'mediaDevices', {
    configurable: true,
    value: { getUserMedia: vi.fn() },
  });
  events = {};
  recording = {
    startRecording: vi.fn().mockResolvedValue(),
    stopRecording: vi.fn(),
    stopMic: vi.fn(),
    on: vi.fn((name, action) => {
      events[name] = action;
    }),
  };
  wave = {
    plugins: [recording],
    on: vi.fn(),
    load: vi.fn(),
    playPause: vi.fn(),
    destroy: vi.fn(),
  };
  WaveSurfer.create.mockReturnValue(wave);
  URL.createObjectURL = vi.fn().mockReturnValue('blob:audio');
  URL.revokeObjectURL = vi.fn();
});
afterEach(() => {
  wrapper?.unmount();
  vi.unstubAllGlobals();
});

it('handles a denied microphone permission without an unhandled rejection', async () => {
  recording.startRecording.mockRejectedValue(
    new DOMException('Denied', 'NotAllowedError')
  );
  wrapper = mount(AudioRecorder, { props: { audioRecordFormat: 'audio/ogg' } });
  await flushPromises();
  expect(wrapper.emitted('recordError')[0][0].error.name).toBe(
    'NotAllowedError'
  );
  expect(wrapper.emitted('finishRecord')).toBeUndefined();
});

it('reports an unsupported browser without starting a recorder', async () => {
  vi.stubGlobal('MediaRecorder', undefined);
  wrapper = mount(AudioRecorder, { props: { audioRecordFormat: 'audio/ogg' } });
  await flushPromises();
  expect(wrapper.emitted('recordError')[0][0].error.message).toBe(
    'AUDIO_RECORDING_UNSUPPORTED'
  );
  expect(WaveSurfer.create).not.toHaveBeenCalled();
});

it('releases a microphone permission that resolves after the user cancels the recorder', async () => {
  let grantPermission;
  recording.startRecording.mockReturnValue(
    new Promise(resolve => {
      grantPermission = resolve;
    })
  );
  wrapper = mount(AudioRecorder, { props: { audioRecordFormat: 'audio/ogg' } });
  wrapper.unmount();
  grantPermission();
  await flushPromises();
  expect(recording.stopMic).toHaveBeenCalledOnce();
  expect(wrapper.emitted('finishRecord')).toBeUndefined();
  wrapper = null;
});

it('stops, converts and previews actual returned MIME bytes before returning a file to the native uploader', async () => {
  convertAudio.mockResolvedValue(new Blob(['audio'], { type: 'audio/mpeg' }));
  wrapper = mount(AudioRecorder, { props: { audioRecordFormat: 'audio/ogg' } });
  await flushPromises();
  wrapper.vm.stopRecording();
  expect(recording.stopRecording).toHaveBeenCalledOnce();
  await events['record-end'](new Blob(['recording'], { type: 'audio/webm' }));
  const [file] = wrapper.emitted('finishRecord')[0];
  expect(file.type).toBe('audio/mpeg');
  expect(file.name).toMatch(/\.mp3$/);
  expect(file.file).toBeInstanceOf(File);
  wrapper.vm.playPause();
  expect(wave.playPause).toHaveBeenCalledOnce();
  wrapper.unmount();
  expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:audio');
  expect(wave.destroy).toHaveBeenCalledOnce();
  wrapper = null;
});
