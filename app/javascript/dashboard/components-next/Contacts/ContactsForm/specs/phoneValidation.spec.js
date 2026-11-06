import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import PhoneNumberInput from '../../../phonenumberinput/PhoneNumberInput.vue';

let wrapper;
let timeZone;

beforeEach(() => {
  timeZone = 'UTC';
  const resolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions;
  vi.spyOn(Intl.DateTimeFormat.prototype, 'resolvedOptions').mockImplementation(
    function resolveOptions() {
      return { ...resolvedOptions.call(this), timeZone };
    }
  );
});
afterEach(() => {
  wrapper?.unmount();
  vi.restoreAllMocks();
});

const open = (value = '') => {
  wrapper = mount({
    components: { PhoneNumberInput },
    setup() {
      return { phone: ref(value), validation: useVuelidate() };
    },
    template: '<PhoneNumberInput v-model="phone" />',
  });
  return wrapper.findComponent(PhoneNumberInput);
};

it.each(['UTC', 'America/Sao_Paulo'])(
  'allows an optional empty phone without blocking the parent form in %s',
  async zone => {
    timeZone = zone;
    open();
    await flushPromises();
    expect(wrapper.vm.validation.$invalid).toBe(false);
    expect(await wrapper.vm.validation.$validate()).toBe(true);
    expect(wrapper.vm.phone).toBe('');
  }
);

it('requires a recognized dial code for a filled phone when the timezone has no country', async () => {
  const phone = open();
  await phone.get('input').setValue('11988887777');
  await flushPromises();
  expect(wrapper.vm.validation.$invalid).toBe(true);
  expect(await wrapper.vm.validation.$validate()).toBe(false);
  expect(phone.emitted('update:modelValue')).toBeUndefined();
  await phone.get('button').trigger('click');
  phone.findComponent({ name: 'DropdownMenu' }).vm.$emit('action', {
    value: 'BR',
    dialCode: '+55',
  });
  await flushPromises();
  expect(await wrapper.vm.validation.$validate()).toBe(true);
  expect(wrapper.vm.phone).toBe('+5511988887777');
});

it.each(['a1', '1'])(
  'rejects an invalid phone %s without replacing the last valid model',
  async invalidPhone => {
    const phone = open('+5511988887777');
    await flushPromises();
    expect(wrapper.vm.validation.$invalid).toBe(false);
    await phone.get('input').setValue(invalidPhone);
    await flushPromises();
    expect(wrapper.vm.validation.$invalid).toBe(true);
    expect(await wrapper.vm.validation.$validate()).toBe(false);
    expect(wrapper.vm.phone).toBe('+5511988887777');
  }
);

it('rejects an unrecognized dial code even with valid digits', async () => {
  const phone = open();
  await phone.get('input').setValue('11988887777');
  await phone.get('button').trigger('click');
  phone.findComponent({ name: 'DropdownMenu' }).vm.$emit('action', {
    value: 'BR',
    dialCode: '+999',
  });
  await flushPromises();
  expect(await wrapper.vm.validation.$validate()).toBe(false);
  expect(phone.emitted('update:modelValue')).toBeUndefined();
});

it.each(['UTC', 'America/Sao_Paulo'])(
  'preserves a valid existing international number in %s',
  async zone => {
    timeZone = zone;
    open('+5511988887777');
    await flushPromises();
    expect(await wrapper.vm.validation.$validate()).toBe(true);
    expect(wrapper.vm.phone).toBe('+5511988887777');
  }
);

it('allows clearing an optional phone after a missing dial code error', async () => {
  const phone = open();
  await phone.get('input').setValue('11988887777');
  await flushPromises();
  expect(wrapper.vm.validation.$invalid).toBe(true);
  await phone.get('input').setValue('');
  await flushPromises();
  expect(await wrapper.vm.validation.$validate()).toBe(true);
  expect(wrapper.vm.phone).toBe('');
});
