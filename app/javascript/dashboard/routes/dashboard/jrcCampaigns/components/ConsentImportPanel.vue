<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';

const emit = defineEmits(['imported']);
const { t } = useI18n();
const csv = ref('');
const preview = ref(null);
const confirmed = ref(false);
const busy = ref(false);
const error = ref('');
const result = ref(null);
const canImport = computed(
  () =>
    !busy.value &&
    confirmed.value &&
    preview.value?.ready > 0 &&
    preview.value?.errors === 0
);
const showError = failure => {
  error.value =
    failure?.response?.data?.errors?.join(', ') ||
    t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED');
};
const selectFile = async event => {
  csv.value = '';
  preview.value = null;
  confirmed.value = false;
  error.value = '';
  result.value = null;
  const file = event.target.files?.[0];
  if (!file) return;
  if (file.size > 1024 * 1024) {
    error.value = t('JRC_CAMPAIGNS.CONSENT_IMPORT.SIZE_ERROR');
    return;
  }
  busy.value = true;
  try {
    csv.value = await file.text();
    const { data } = await JrcCampaignsAPI.previewConsentImport(csv.value);
    preview.value = data;
  } catch (failure) {
    showError(failure);
  } finally {
    busy.value = false;
  }
};
const importCsv = async () => {
  if (!canImport.value) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await JrcCampaignsAPI.importConsents(
      csv.value,
      confirmed.value
    );
    result.value = data;
    preview.value = null;
    csv.value = '';
    confirmed.value = false;
    emit('imported');
  } catch (failure) {
    showError(failure);
    confirmed.value = false;
  } finally {
    busy.value = false;
  }
};
const downloadTemplate = () => {
  const url = URL.createObjectURL(
    new Blob(['\uFEFFphone_number,source,granted_at,evidence\r\n'], {
      type: 'text/csv;charset=utf-8',
    })
  );
  const link = document.createElement('a');
  link.href = url;
  link.download = 'consentimentos.csv';
  link.click();
  URL.revokeObjectURL(url);
};
</script>

<template>
  <section class="mt-6 space-y-4 rounded-xl border border-n-weak p-5">
    <h2 class="text-xl font-semibold text-n-slate-12">
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.TITLE') }}
    </h2>
    <p class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.HELP') }}
    </p>
    <p class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.FORMAT') }}
    </p>
    <button
      type="button"
      class="rounded-lg border border-n-strong px-3 py-2 text-n-slate-12"
      @click="downloadTemplate"
    >
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.TEMPLATE') }}
    </button>
    <label class="flex flex-col gap-2 text-sm text-n-slate-12">
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.FILE') }}
      <input
        type="file"
        accept=".csv,text/csv"
        :disabled="busy"
        @change="selectFile"
      />
    </label>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <p v-if="result" role="status" class="text-sm text-n-teal-11">
      {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.RESULT', result) }}
    </p>
    <template v-if="preview">
      <p role="status" class="text-sm text-n-slate-12">
        {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.SUMMARY', preview) }}
      </p>
      <div class="max-h-72 overflow-auto">
        <table class="w-full text-left text-sm text-n-slate-12">
          <thead>
            <tr>
              <th class="p-2">{{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.LINE') }}</th>
              <th class="p-2">{{ t('JRC_CAMPAIGNS.BLACKLIST.PHONE') }}</th>
              <th class="p-2">
                {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.STATUS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in preview.rows"
              :key="row.line"
              class="border-t border-n-weak"
            >
              <td class="p-2">{{ row.line }}</td>
              <td class="p-2">{{ row.phone_number }}</td>
              <td class="p-2">
                {{
                  row.reason ||
                  (row.status === 'ready'
                    ? t('JRC_CAMPAIGNS.CONSENT_IMPORT.READY')
                    : t('JRC_CAMPAIGNS.CONSENT_IMPORT.EXISTING'))
                }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <label class="flex items-start gap-2 text-sm text-n-slate-12">
        <input
          v-model="confirmed"
          type="checkbox"
          :disabled="busy || preview.errors > 0"
        />
        {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.CONFIRM') }}
      </label>
      <button
        type="button"
        :disabled="!canImport"
        class="rounded-lg bg-n-brand px-4 py-2 text-white disabled:opacity-40"
        @click="importCsv"
      >
        {{ t('JRC_CAMPAIGNS.CONSENT_IMPORT.IMPORT') }}
      </button>
    </template>
  </section>
</template>
