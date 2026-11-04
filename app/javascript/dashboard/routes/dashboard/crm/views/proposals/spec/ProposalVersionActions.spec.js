import { mount } from '@vue/test-utils';
import ProposalVersionActions from '../ProposalVersionActions.vue';
import messages from 'dashboard/i18n/locale/en/crm.json';

it.each([false, true])(
  'keeps the three primary actions accessible for historical=%s',
  async historical => {
    const wrapper = mount(ProposalVersionActions, { props: { historical } });
    expect(wrapper.text()).toContain(messages.CRM.VERSIONS.EDIT);
    expect(wrapper.text()).toContain(messages.CRM.VERSIONS.RESEND);
    expect(wrapper.text()).toContain(messages.CRM.VERSIONS.HISTORY);
    await Promise.all(
      ['revise', 'resend', 'history'].map(async action => {
        await wrapper.get(`[data-version-action="${action}"]`).trigger('click');
        expect(wrapper.emitted(action)).toHaveLength(1);
      })
    );
    expect(wrapper.find('[role="status"]').exists()).toBe(historical);
    wrapper.unmount();
  }
);

it('prevents duplicate actions while a request is pending', async () => {
  const wrapper = mount(ProposalVersionActions, {
    props: { historical: true, busy: true },
  });
  await Promise.all(
    wrapper.findAll('button').map(async button => {
      expect(button.attributes('disabled')).toBeDefined();
      await button.trigger('click');
    })
  );
  expect(wrapper.emitted('revise')).toBeUndefined();
  expect(wrapper.emitted('resend')).toBeUndefined();
  wrapper.unmount();
});
