import { ref } from 'vue';
import { shallowMount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createRouter, createMemoryHistory } from 'vue-router';
import ContactsForm from '../ContactsForm.vue';
import MasterCompanyPicker from 'dashboard/routes/dashboard/jrcCustomers/components/CompanyPicker.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    currentAccount: ref({ id: 1 }),
    isCloudFeatureEnabled: flag => flag === FEATURE_FLAGS.JRC_CUSTOMER_MASTER,
  }),
}));
it('selects a canonical company for a new native contact, with profile fields preserved', async () => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/app/accounts/:accountId', component: { template: '<div />' } },
    ],
  });
  await router.push('/app/accounts/1');
  const store = createStore({ getters: { getCurrentUser: () => ({ id: 7 }) } });
  const wrapper = shallowMount(ContactsForm, {
    props: { isNewContact: true },
    global: { plugins: [store, router] },
  });
  const state = wrapper.vm.$.setupState.state;
  state.firstName = 'Synthetic';
  state.additionalAttributes.city = 'Test city';
  wrapper
    .findComponent(MasterCompanyPicker)
    .vm.$emit('selected', { id: 12, name: 'Registered synthetic company' });
  await flushPromises();
  expect(state.companyId).toBe(12);
  expect(state.additionalAttributes.companyName).toBe(
    'Registered synthetic company'
  );
  expect(state.additionalAttributes.city).toBe('Test city');
  wrapper.unmount();
});
