import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyEditor from './components/CompanyEditor.vue';
import API from 'dashboard/api/jrcCustomers';
import { FIELD_LABELS } from './copy';

vi.mock('dashboard/api/jrcCustomers', () => ({
  default: { metadata: vi.fn(), saveCompany: vi.fn() },
}));

it('loads and saves the full company address through the native company form', async () => {
  API.metadata.mockResolvedValue({ data: { owners: [], segments: [] } });
  API.saveCompany.mockResolvedValue({ data: { payload: { id: 12 } } });
  const address = {
    postal_code: '88000-000',
    street: 'Rua Sintética',
    number: '12',
    complement: 'Sala 3',
    district: 'Centro',
    city: 'Florianópolis',
    state: 'SC',
    country: 'BR',
  };
  const wrapper = shallowMount(CompanyEditor, {
    props: {
      company: {
        id: 12,
        name: 'Synthetic',
        revision: 'revision',
        primary_address: address,
      },
    },
  });
  await flushPromises();
  Object.entries(address).forEach(([key, value]) => {
    const label = wrapper
      .findAll('label')
      .find(item => item.text().trim() === FIELD_LABELS[key]);
    expect(label.get('input').element.value).toBe(value);
  });
  await wrapper.get('form').trigger('submit');
  await flushPromises();
  expect(API.saveCompany).toHaveBeenCalledWith(
    expect.objectContaining({ primary_address: address, revision: 'revision' }),
    12
  );
  expect(wrapper.emitted('saved')).toEqual([[{ id: 12 }]]);
  wrapper.unmount();
});
