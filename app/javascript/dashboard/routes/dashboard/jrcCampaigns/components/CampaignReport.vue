<script setup>
import { onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';

const props = defineProps({ campaign: { type: Object, required: true } });
const emit = defineEmits(['close']);
const { t } = useI18n();
const refreshing = ref(false);
const loading = ref(true);
const report = ref(null);
const page = ref(1);

const load = async (targetPage, silent = false) => {
  if (refreshing.value) return;
  refreshing.value = true;
  if (!report.value) loading.value = true;
  try {
    const { data } = await JrcCampaignsAPI.report(props.campaign.id, {
      page: targetPage,
      per_page: 50,
    });
    report.value = data;
    page.value = targetPage;
  } catch {
    if (!silent) useAlert(t('JRC_CAMPAIGNS.ALERTS.REPORT_LOAD_FAILED'));
  } finally {
    refreshing.value = false;
    loading.value = false;
  }
};

const errorKeysByCode = new Map([
  ['131049', 'ECOSYSTEM'],
  ['131026', 'UNDELIVERABLE'],
]);
const legacyErrorKeys = new Map([
  [
    'this message was not delivered to maintain healthy ecosystem engagement',
    'ECOSYSTEM',
  ],
  ['message undeliverable', 'UNDELIVERABLE'],
]);
const errorMessage = recipient => {
  const original = String(recipient.error_message || '')
    .trim()
    .toLowerCase()
    .replace(/[.\s]+$/, '');
  const key = recipient.error_code
    ? errorKeysByCode.get(String(recipient.error_code))
    : legacyErrorKeys.get(original);
  return t(`JRC_CAMPAIGNS.REPORTS.ERROR_MESSAGES.${key || 'UNKNOWN'}`);
};

const exportReport = () => {
  window.open(JrcCampaignsAPI.exportUrl(props.campaign.id), '_blank');
};

let refreshTimer;
onMounted(() => {
  load(1);
  refreshTimer = setInterval(() => load(page.value, true), 15000);
});
onUnmounted(() => clearInterval(refreshTimer));
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-stretch justify-end bg-n-slate-12/40"
    role="dialog"
    aria-modal="true"
    :aria-label="$t('JRC_CAMPAIGNS.REPORT_LAYOUT.DETAIL_TITLE')"
  >
    <div
      class="flex h-full min-w-0 w-full max-w-7xl flex-col bg-n-background text-n-slate-12 shadow-xl"
    >
      <div
        class="flex shrink-0 flex-wrap items-start justify-between gap-4 border-b border-n-weak px-4 py-4 sm:px-6"
      >
        <div class="min-w-0">
          <p class="m-0 text-sm font-semibold text-n-teal-11">
            {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.DETAIL_TITLE') }}
          </p>
          <div class="mt-1 flex flex-wrap items-center gap-3">
            <h2 class="m-0 break-words text-2xl font-bold sm:text-3xl">
              {{ campaign.name }}
            </h2>
            <span
              v-if="campaign.status"
              class="rounded-full px-3 py-1 text-sm font-semibold"
              :class="
                campaign.status === 'completed'
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-12'
              "
            >
              {{ $t(`JRC_CAMPAIGNS.STATUS.${campaign.status}`) }}
            </span>
          </div>
          <p class="mb-0 mt-2 text-sm text-n-slate-11">
            {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.AUTO_REFRESH') }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <button
            type="button"
            class="flex items-center gap-2 rounded-lg border border-n-strong px-3 py-2 text-sm text-n-slate-12 disabled:opacity-50"
            :disabled="refreshing"
            @click="load(page)"
          >
            <span class="i-lucide-refresh-cw size-4" />
            {{ $t('JRC_CAMPAIGNS.REFRESH') }}
          </button>
          <button
            type="button"
            class="flex items-center gap-2 rounded-lg border border-n-strong px-3 py-2 text-sm text-n-slate-12"
            @click="exportReport"
          >
            <span class="i-lucide-download size-4" />
            {{ $t('JRC_CAMPAIGNS.EXPORT') }}
          </button>
          <button
            type="button"
            class="rounded-lg p-2 text-n-slate-12 hover:bg-n-alpha-2"
            :aria-label="$t('JRC_CAMPAIGNS.CLOSE')"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </div>
      </div>
      <div class="min-h-0 flex-1 overflow-y-auto overscroll-contain p-4 sm:p-6">
        <div v-if="loading" class="p-12 text-center text-sm text-n-slate-11">
          {{ $t('JRC_CAMPAIGNS.LOADING') }}
        </div>
        <template v-else-if="report">
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-6">
            <div
              v-for="item in [
                [
                  'TOTAL',
                  report.summary.total,
                  'bg-n-teal-2 text-n-teal-11',
                  'i-lucide-users-round',
                ],
                [
                  'SENT',
                  report.summary.sent,
                  'bg-n-blue-2 text-n-blue-11',
                  'i-lucide-send',
                ],
                [
                  'DELIVERED',
                  report.summary.delivered,
                  'bg-emerald-50 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200',
                  'i-lucide-circle-check',
                ],
                [
                  'READ',
                  report.summary.read,
                  'bg-n-violet-2 text-n-violet-11',
                  'i-lucide-eye',
                ],
                [
                  'REPLIED',
                  report.summary.replied,
                  'bg-n-teal-2 text-n-teal-11',
                  'i-lucide-messages-square',
                ],
                [
                  'FAILED',
                  report.summary.failed,
                  'bg-n-ruby-2 text-n-ruby-11',
                  'i-lucide-triangle-alert',
                ],
              ]"
              :key="item[0]"
              class="flex min-w-0 items-start gap-3 rounded-xl border border-n-weak p-4"
              :class="item[2]"
            >
              <span class="mt-1 size-6 shrink-0" :class="item[3]" />
              <div class="min-w-0">
                <div class="text-sm font-medium">
                  {{ $t(`JRC_CAMPAIGNS.REPORTS.${item[0]}`) }}
                </div>
                <div class="mt-1 text-2xl font-bold tabular-nums">
                  {{ new Intl.NumberFormat().format(Number(item[1] || 0)) }}
                </div>
              </div>
            </div>
          </div>

          <p
            class="my-4 flex items-center gap-2 rounded-xl bg-n-blue-2 p-3 text-sm text-n-blue-11"
          >
            <span class="i-lucide-info size-4 shrink-0" />
            {{ $t('JRC_CAMPAIGNS.REPORTS.READ_RECEIPT_HELP') }}
          </p>
          <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h3 class="m-0 text-lg font-semibold">
              {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.RECIPIENT_RESULTS') }}
            </h3>
            <span class="text-sm text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.ALL_RESULTS') }}
            </span>
          </div>
          <div class="overflow-x-auto rounded-xl border border-n-weak">
            <table class="w-full min-w-[900px] text-left text-sm">
              <thead class="bg-n-alpha-2 text-sm text-n-slate-12">
                <tr>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.TABLE.NAME') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.DESTINATION') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.INBOX') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.EXECUTION') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.STATUS') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.SENT_AT') }}
                  </th>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.ERROR') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="recipient in report.recipients"
                  :key="recipient.id"
                  class="border-t border-n-weak hover:bg-n-teal-2/30"
                >
                  <td
                    class="min-w-[140px] px-4 py-3 font-medium text-n-slate-12"
                  >
                    {{ recipient.name || '-' }}
                  </td>
                  <td class="px-4 py-3 text-n-slate-12">
                    {{
                      recipient.destination ||
                      recipient.email ||
                      recipient.phone_number
                    }}
                  </td>
                  <td class="px-4 py-3 text-n-slate-12">
                    {{ recipient.inbox_name || '-' }}
                  </td>
                  <td class="px-4 py-3 text-n-slate-12">
                    #{{ recipient.execution_number }}
                  </td>
                  <td class="px-4 py-3">
                    <span
                      class="inline-flex rounded-full px-3 py-1 text-sm font-medium"
                      :class="
                        recipient.status === 'failed'
                          ? 'bg-n-ruby-3 text-n-ruby-11'
                          : recipient.status === 'read'
                            ? 'bg-n-violet-3 text-n-violet-11'
                            : ['delivered', 'replied'].includes(
                                  recipient.status
                                )
                              ? 'bg-n-teal-3 text-n-teal-11'
                              : 'bg-n-alpha-2 text-n-slate-12'
                      "
                    >
                      {{
                        $t(`JRC_CAMPAIGNS.RECIPIENT_STATUS.${recipient.status}`)
                      }}
                    </span>
                  </td>
                  <td class="px-4 py-3 text-n-slate-11">
                    {{
                      recipient.sent_at
                        ? new Date(recipient.sent_at).toLocaleString(
                            undefined,
                            {
                              timeZone: report.timezone || 'UTC',
                              timeZoneName: 'short',
                            }
                          )
                        : '-'
                    }}
                  </td>
                  <td class="max-w-sm px-4 py-3 text-sm text-n-ruby-11">
                    <template
                      v-if="recipient.error_message || recipient.error_code"
                    >
                      <p
                        class="line-clamp-2 font-medium"
                        :title="errorMessage(recipient)"
                      >
                        {{ errorMessage(recipient) }}
                      </p>
                      <p v-if="recipient.error_code" class="mt-1 font-semibold">
                        {{
                          $t('JRC_CAMPAIGNS.REPORTS.ERROR_CODE', {
                            code: recipient.error_code,
                          })
                        }}
                      </p>
                      <details
                        v-if="recipient.error_message"
                        class="mt-2 text-n-slate-12"
                      >
                        <summary
                          class="cursor-pointer font-medium text-n-teal-11 underline"
                        >
                          {{ $t('JRC_CAMPAIGNS.REPORTS.ERROR_DETAILS') }}
                        </summary>
                        <p
                          class="mt-2 break-words rounded-lg bg-n-ruby-2 p-3 text-sm text-n-slate-12"
                        >
                          {{ recipient.error_message }}
                        </p>
                        <p class="mt-2 text-sm leading-6 text-n-slate-12">
                          {{ errorMessage(recipient) }}
                        </p>
                      </details>
                    </template>
                    <template v-else>-</template>
                  </td>
                </tr>
                <tr v-if="!report.recipients.length">
                  <td
                    colspan="7"
                    class="p-10 text-center text-sm text-n-slate-11"
                  >
                    {{ $t('JRC_CAMPAIGNS.REPORTS.NO_DATA') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
            <p class="m-0 text-sm text-n-slate-11">
              {{
                $t('JRC_CAMPAIGNS.REPORT_LAYOUT.PAGE_NOTE', {
                  page,
                  pages: report.pagination.pages,
                  count: report.recipients.length,
                })
              }}
            </p>
            <div
              v-if="report.pagination.pages > 1"
              class="flex items-center gap-2"
            >
              <button
                type="button"
                class="rounded-lg border border-n-weak px-3 py-1.5 text-sm disabled:opacity-40"
                :aria-label="$t('JRC_CAMPAIGNS.REPORT_LAYOUT.PREVIOUS_PAGE')"
                :disabled="page <= 1"
                @click="load(page - 1)"
              >
                <span class="i-lucide-chevron-left size-4" aria-hidden="true" />
              </button>
              <span class="px-2 py-1.5 text-sm text-n-slate-11">
                {{ page }} / {{ report.pagination.pages }}
              </span>
              <button
                type="button"
                class="rounded-lg border border-n-weak px-3 py-1.5 text-sm disabled:opacity-40"
                :aria-label="$t('JRC_CAMPAIGNS.REPORT_LAYOUT.NEXT_PAGE')"
                :disabled="page >= report.pagination.pages"
                @click="load(page + 1)"
              >
                <span
                  class="i-lucide-chevron-right size-4"
                  aria-hidden="true"
                />
              </button>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
