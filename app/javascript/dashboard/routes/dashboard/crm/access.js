import store from 'dashboard/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export const ensureCrmEnabled = async to => {
  const accountId = Number(to.params.accountId);
  const currentUser = store.getters.getCurrentUser || {};
  const account = currentUser.accounts?.find(
    item => Number(item.id) === accountId
  );
  const hasUserAccess =
    account?.role === 'administrator' ||
    account?.permissions?.includes('jrc_crm');

  if (!hasUserAccess) {
    return frontendURL(`accounts/${accountId}/dashboard`);
  }

  await store.dispatch('accounts/get', { accountId, silent: true });
  const enabled = store.getters['accounts/isFeatureEnabledonAccount'](
    accountId,
    FEATURE_FLAGS.JRC_CRM
  );
  return enabled ? true : frontendURL(`accounts/${accountId}/dashboard`);
};
