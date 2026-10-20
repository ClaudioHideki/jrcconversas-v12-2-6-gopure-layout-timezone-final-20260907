<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';
import TestAuthorizationPanel from './TestAuthorizationPanel.vue';

const { t } = useI18n();
const entries = ref([]);
const saving = ref(false);
const phoneInput = ref(null);
const form = reactive({
  phone_number: '',
  evidence: '',
  operator_confirmed: false,
  supersedes_id: null,
});
watch(
  () => form.phone_number,
  () => {
    form.operator_confirmed = false;
  }
);
const resetForm = () => {
  Object.assign(form, {
    phone_number: '',
    evidence: '',
    operator_confirmed: false,
    supersedes_id: null,
  });
};
const reconfirm = entry => {
  Object.assign(form, {
    phone_number: entry.phone_number,
    evidence: '',
    operator_confirmed: false,
    supersedes_id: entry.id,
  });
  phoneInput.value?.focus();
};
const load = async () => {
  try {
    const { data } = await JrcCampaignsAPI.consents();
    entries.value = data;
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  }
};
const add = async () => {
  if (saving.value || !form.operator_confirmed) return;
  saving.value = true;
  try {
    await JrcCampaignsAPI.createConsent({ ...form });
    resetForm();
    useAlert(t('JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_RECORDED'));
    await load();
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  } finally {
    saving.value = false;
  }
};
const revoke = async id => {
  try {
    await JrcCampaignsAPI.revokeConsent(id);
    await load();
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  }
};
onMounted(load);
</script>

<template>
  <section class="mt-8 space-y-4 rounded-xl border border-n-weak p-5">
    <h2 class="text-xl font-semibold text-n-slate-12">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_TITLE') }}
    </h2>
    <p class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONSENT_HELP') }}
    </p>
    <p
      v-if="form.supersedes_id"
      class="rounded-lg bg-n-amber-2 p-3 text-sm text-n-slate-12"
    >
      {{
        t('JRC_CAMPAIGNS.GOVERNANCE.RECONFIRM_HELP', { id: form.supersedes_id })
      }}
    </p>
    <form class="flex flex-col gap-3" @submit.prevent="add">
      <input
        ref="phoneInput"
        v-model="form.phone_number"
        required
        :readonly="Boolean(form.supersedes_id)"
        class="rounded-lg border border-n-weak bg-n-background px-3 py-2"
        :aria-label="t('JRC_CAMPAIGNS.BLACKLIST.PHONE')"
        :placeholder="t('JRC_CAMPAIGNS.BLACKLIST.PHONE')"
      />
      <textarea
        v-model="form.evidence"
        required
        class="rounded-lg border border-n-weak bg-n-background px-3 py-2"
        :aria-label="t('JRC_CAMPAIGNS.GOVERNANCE.EVIDENCE')"
        :placeholder="t('JRC_CAMPAIGNS.GOVERNANCE.EVIDENCE')"
      />
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input v-model="form.operator_confirmed" type="checkbox" required />
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_CONFIRM') }}
      </label>
      <button
        type="submit"
        class="rounded-lg bg-n-brand px-4 py-2 text-white disabled:opacity-40"
        :disabled="
          saving ||
          !form.phone_number.trim() ||
          !form.evidence.trim() ||
          !form.operator_confirmed
        "
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.RECORD_CONSENT') }}
      </button>
      <button
        v-if="form.supersedes_id"
        type="button"
        class="rounded-lg border border-n-strong px-3 py-2 text-n-slate-12"
        @click="resetForm"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.CANCEL_RECONFIRM') }}
      </button>
    </form>
    <div
      v-for="entry in entries"
      :key="entry.id"
      class="space-y-2 border-t border-n-weak py-3 text-sm text-n-slate-12"
    >
      <div>
        <p class="font-medium">{{ entry.phone_number }}</p>
        <p>{{ `${entry.evidence} · ${entry.granted_at}` }}</p>
      </div>
      <p v-if="entry.superseded_by_id">
        {{
          t('JRC_CAMPAIGNS.GOVERNANCE.SUPERSEDED', {
            id: entry.superseded_by_id,
          })
        }}
      </p>
      <p v-else-if="entry.revoked_at">
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.REVOKED') }}
      </p>
      <p
        v-else-if="entry.purpose === 'whatsapp_campaigns'"
        class="text-n-teal-11"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.CONTINUOUS_ACTIVE') }}
      </p>
      <p v-else class="text-n-amber-11">
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.PURPOSE_UNCONFIRMED') }}
      </p>
      <p v-if="entry.supersedes_id">
        {{
          t('JRC_CAMPAIGNS.GOVERNANCE.SUPERSEDES', { id: entry.supersedes_id })
        }}
      </p>
      <button
        v-if="!entry.revoked_at && entry.purpose !== 'whatsapp_campaigns'"
        type="button"
        class="rounded-lg border border-n-brand px-3 py-2 text-n-brand"
        @click="reconfirm(entry)"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.RECONFIRM') }}
      </button>
      <button
        v-if="!entry.revoked_at"
        type="button"
        class="rounded-lg px-3 py-2 text-n-ruby-11 hover:bg-n-ruby-3"
        @click="revoke(entry.id)"
      >
        {{ t('JRC_CAMPAIGNS.GOVERNANCE.REVOKE') }}
      </button>
    </div>
  </section>
  <details class="mt-6 rounded-xl border border-n-weak p-5">
    <summary class="cursor-pointer font-medium text-n-slate-12">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.SINGLE_TEST_OPTION') }}
    </summary>
    <TestAuthorizationPanel />
  </details>
</template>
