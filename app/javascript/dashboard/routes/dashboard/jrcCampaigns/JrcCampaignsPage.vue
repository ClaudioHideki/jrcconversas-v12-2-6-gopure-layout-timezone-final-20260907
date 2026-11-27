<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';
import CampaignWizard from './components/CampaignWizard.vue';
import CampaignReport from './components/CampaignReport.vue';
import CampaignPerformanceChart from './components/CampaignPerformanceChart.vue';
import SanitizedLists from './components/SanitizedLists.vue';
import BlacklistPanel from './components/BlacklistPanel.vue';
import CampaignApproval from './components/CampaignApproval.vue';
import CampaignActions from './components/CampaignActions.vue';

const { t } = useI18n();
const campaigns = ref([]);
const metadata = ref({
  labels: [],
  source_inboxes: [],
  inboxes: [],
  whatsapp_inboxes: [],
  email_inboxes: [],
  pipelines: [],
  sanitized_lists: [],
  contacts_count: 0,
  blacklist_count: 0,
});
const analytics = ref({
  summary: { sent: 0, delivered: 0, read: 0, replied: 0, failed: 0 },
  previous_summary: { sent: 0, delivered: 0, read: 0, replied: 0, failed: 0 },
  series: [],
  failure_reasons: [],
});
const loading = ref(false);
const analyticsLoading = ref(false);
const activeTab = ref('dispatches');
const showWizard = ref(false);
const editingCampaign = ref(null);
const initialListId = ref(null);
const reportCampaign = ref(null);
const reviewCampaign = ref(null);
const period = ref('30');
const campaignFilter = ref('');
const channelFilter = ref('');
const showAdvancedFilters = ref(false);
const statusFilters = ref([]);
const deletingCampaignIds = ref([]);

const tabs = computed(() => [
  {
    key: 'dispatches',
    label: t('JRC_CAMPAIGNS.TABS.DISPATCHES'),
    icon: 'i-lucide-send',
  },
  {
    key: 'sanitize',
    label: t('JRC_CAMPAIGNS.TABS.SANITIZE'),
    icon: 'i-lucide-list-checks',
  },
  {
    key: 'blacklist',
    label: t('JRC_CAMPAIGNS.TABS.BLACKLIST'),
    icon: 'i-lucide-shield-ban',
  },
  {
    key: 'reports',
    label: t('JRC_CAMPAIGNS.TABS.REPORTS'),
    icon: 'i-lucide-chart-no-axes-column-increasing',
  },
]);

const dashboardMetrics = computed(() => [
  {
    key: 'sent',
    label: t('JRC_CAMPAIGNS.KPIS.SENT'),
    icon: 'i-lucide-send',
    iconClass: 'bg-n-blue-3 text-n-blue-11',
    cardClass: 'from-n-blue-2/80',
  },
  {
    key: 'delivered',
    label: t('JRC_CAMPAIGNS.KPIS.DELIVERED'),
    icon: 'i-lucide-message-square-check',
    iconClass:
      'bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200',
    cardClass: 'from-emerald-50 dark:from-emerald-950/40',
  },
  {
    key: 'read',
    label: t('JRC_CAMPAIGNS.KPIS.READ'),
    icon: 'i-lucide-badge-check',
    iconClass: 'bg-n-violet-3 text-n-violet-11',
    cardClass: 'from-n-violet-2/80',
  },
  {
    key: 'replied',
    label: t('JRC_CAMPAIGNS.KPIS.REPLIES'),
    icon: 'i-lucide-messages-square',
    iconClass: 'bg-n-teal-3 text-n-teal-11',
    cardClass: 'from-n-teal-2/80',
  },
  {
    key: 'failed',
    label: t('JRC_CAMPAIGNS.KPIS.FAILURES'),
    icon: 'i-lucide-circle-alert',
    iconClass: 'bg-n-ruby-3 text-n-ruby-11',
    cardClass: 'from-n-ruby-2/80',
  },
]);

const funnel = computed(() => {
  const summary = analytics.value.summary;
  return ['sent', 'delivered', 'read', 'replied'].map(key => {
    let percentage = 0;
    if (summary.sent) {
      percentage =
        key === 'sent'
          ? 100
          : Math.round(
              (Number(summary[key] || 0) / Number(summary.sent)) * 1000
            ) / 10;
    }
    return {
      key,
      label: t(`JRC_CAMPAIGNS.FUNNEL.${key.toUpperCase()}`),
      value: Number(summary[key] || 0),
      percentage,
    };
  });
});

const visibleFailureReasons = computed(() =>
  analytics.value.failure_reasons.filter(item => Number(item.count) > 0)
);
const failureTotal = computed(() =>
  visibleFailureReasons.value.reduce(
    (total, item) => total + Number(item.count || 0),
    0
  )
);
const periodStart = computed(() => {
  if (period.value === 'all') return null;
  const date = new Date();
  date.setDate(date.getDate() - Number(period.value) + 1);
  date.setHours(0, 0, 0, 0);
  return date;
});
const filteredCampaigns = computed(() =>
  campaigns.value.filter(campaign => {
    if (
      campaignFilter.value &&
      Number(campaign.id) !== Number(campaignFilter.value)
    )
      return false;
    if (
      statusFilters.value.length &&
      !statusFilters.value.includes(campaign.status)
    )
      return false;
    if (
      channelFilter.value &&
      campaign.delivery_channel !== channelFilter.value
    )
      return false;
    return (
      !periodStart.value || new Date(campaign.created_at) >= periodStart.value
    );
  })
);
const chartMetricLabels = computed(() => ({
  sent: t('JRC_CAMPAIGNS.KPIS.SENT'),
  delivered: t('JRC_CAMPAIGNS.KPIS.DELIVERED'),
  read: t('JRC_CAMPAIGNS.KPIS.READ'),
  replied: t('JRC_CAMPAIGNS.KPIS.REPLIES'),
  failed: t('JRC_CAMPAIGNS.KPIS.FAILURES'),
}));
const statusOptions = computed(() =>
  ['draft', 'scheduled', 'running', 'paused', 'completed', 'canceled'].map(
    status => ({
      status,
      label: t(`JRC_CAMPAIGNS.STATUS.${status}`),
    })
  )
);

const statusLabel = status => t(`JRC_CAMPAIGNS.STATUS.${status}`);
const formatDate = (value, timezone = 'UTC') =>
  value
    ? new Date(value).toLocaleString(undefined, {
        timeZone: timezone,
        timeZoneName: 'short',
      })
    : t('JRC_CAMPAIGNS.NOT_AVAILABLE');
const formatNumber = value =>
  new Intl.NumberFormat(undefined).format(Number(value || 0));
const formatPercent = value =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 }).format(
    Number(value || 0)
  );
const metricRate = key =>
  analytics.value.summary.sent
    ? Math.round(
        (Number(analytics.value.summary[key] || 0) /
          Number(analytics.value.summary.sent)) *
          1000
      ) / 10
    : 0;
const metricDescription = key =>
  key === 'sent'
    ? t('JRC_CAMPAIGNS.KPIS.TOTAL_SENT')
    : t(`JRC_CAMPAIGNS.KPIS.RATE_${key.toUpperCase()}`, {
        rate: formatPercent(metricRate(key)),
      });
const statusClass = status =>
  ({
    completed: 'bg-n-teal-3 text-n-teal-11',
    running: 'bg-n-blue-3 text-n-blue-11',
    scheduled: 'bg-n-violet-3 text-n-violet-11',
    paused: 'bg-n-amber-3 text-n-amber-11',
    canceled: 'bg-n-ruby-3 text-n-ruby-11',
  })[status] || 'bg-n-alpha-2 text-n-slate-12';
const barClass = key =>
  ({
    sent: '[&::-webkit-progress-value]:bg-n-blue-9 [&::-moz-progress-bar]:bg-n-blue-9',
    delivered:
      '[&::-webkit-progress-value]:bg-emerald-500 [&::-moz-progress-bar]:bg-emerald-500',
    read: '[&::-webkit-progress-value]:bg-n-violet-9 [&::-moz-progress-bar]:bg-n-violet-9',
    replied:
      '[&::-webkit-progress-value]:bg-n-teal-9 [&::-moz-progress-bar]:bg-n-teal-9',
  })[key];
const failureBarClass = key =>
  key === 'invalid_number' || key === 'provider'
    ? '[&::-webkit-progress-value]:bg-n-ruby-9 [&::-moz-progress-bar]:bg-n-ruby-9'
    : '[&::-webkit-progress-value]:bg-n-amber-9 [&::-moz-progress-bar]:bg-n-amber-9';
const progress = campaign => {
  const total =
    campaign.latest_execution?.total_count ||
    campaign.estimated_recipients ||
    0;
  const processed =
    Number(campaign.latest_execution?.sent_count || campaign.sent_count || 0) +
    Number(
      campaign.latest_execution?.failed_count || campaign.failed_count || 0
    );
  return total ? Math.min(100, Math.round((processed / total) * 100)) : 0;
};
const fetchAnalytics = async () => {
  analyticsLoading.value = true;
  try {
    const { data } = await JrcCampaignsAPI.analytics({
      period: period.value,
      campaign_id: campaignFilter.value || undefined,
      delivery_channel: channelFilter.value || undefined,
    });
    analytics.value = data;
  } catch {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.ANALYTICS_FAILED'));
  } finally {
    analyticsLoading.value = false;
  }
};
const fetchData = async () => {
  loading.value = true;
  try {
    const [campaignResponse, metadataResponse] = await Promise.all([
      JrcCampaignsAPI.get(),
      JrcCampaignsAPI.metadata(),
    ]);
    campaigns.value = campaignResponse.data;
    metadata.value = metadataResponse.data;
    await fetchAnalytics();
  } catch {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.LOAD_FAILED'));
  } finally {
    loading.value = false;
  }
};
const refreshSenders = async () => {
  try {
    const { data } = await JrcCampaignsAPI.metadata();
    metadata.value = data;
  } catch {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.LOAD_FAILED'));
  }
};
const openNew = () => {
  initialListId.value = null;
  editingCampaign.value = null;
  showWizard.value = true;
};
const openFromList = list => {
  initialListId.value = list.id;
  editingCampaign.value = null;
  showWizard.value = true;
};
const openEdit = campaign => {
  editingCampaign.value = campaign;
  showWizard.value = true;
};
const closeWizard = () => {
  showWizard.value = false;
  editingCampaign.value = null;
};
const saved = async () => {
  closeWizard();
  await fetchData();
};
const reviewSavedCampaign = async campaign => {
  closeWizard();
  reviewCampaign.value = campaign;
  await fetchData();
};
const runAction = async (campaign, action) => {
  if (action === 'launch' && !campaign.approval_valid) {
    reviewCampaign.value = campaign;
    return;
  }
  try {
    await JrcCampaignsAPI[action](campaign.id);
    useAlert(t('JRC_CAMPAIGNS.ALERTS.ACTION_OK'));
    await fetchData();
  } catch (error) {
    useAlert(
      error?.response?.data?.errors?.join(', ') ||
        t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED')
    );
  }
};
const duplicateCampaign = async campaign => {
  try {
    await JrcCampaignsAPI.duplicate(campaign.id);
    useAlert(t('JRC_CAMPAIGNS.ALERTS.DUPLICATED'));
    await fetchData();
  } catch {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED'));
  }
};
const deleteCampaign = async campaign => {
  if (
    ['running', 'paused'].includes(campaign.status) ||
    deletingCampaignIds.value.includes(campaign.id)
  )
    return;
  if (
    !window.confirm(t('JRC_CAMPAIGNS.DELETE_CONFIRM', { name: campaign.name }))
  )
    return;
  deletingCampaignIds.value.push(campaign.id);
  try {
    await JrcCampaignsAPI.delete(campaign.id);
    if (String(campaignFilter.value) === String(campaign.id))
      campaignFilter.value = '';
    useAlert(t('JRC_CAMPAIGNS.ALERTS.DELETED'));
    await fetchData();
  } catch {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED'));
  } finally {
    deletingCampaignIds.value = deletingCampaignIds.value.filter(
      id => id !== campaign.id
    );
  }
};
const toggleStatus = status => {
  const index = statusFilters.value.indexOf(status);
  if (index >= 0) statusFilters.value.splice(index, 1);
  else statusFilters.value.push(status);
};
const exportSelected = () => {
  const campaign = campaigns.value.find(
    item => Number(item.id) === Number(campaignFilter.value)
  );
  if (!campaign) {
    useAlert(t('JRC_CAMPAIGNS.ALERTS.SELECT_EXPORT'));
    return;
  }
  window.open(JrcCampaignsAPI.exportUrl(campaign.id), '_blank');
};

watch([period, campaignFilter, channelFilter], fetchAnalytics);
onMounted(fetchData);
</script>

<template>
  <div
    class="relative h-full w-full shrink-0 overflow-y-auto bg-gradient-to-br from-n-teal-2/40 via-n-background to-n-background text-n-slate-12 p-4 lg:p-6"
  >
    <div v-if="!showWizard" class="w-full">
      <div class="mb-5 flex flex-wrap items-center justify-between gap-4">
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-semibold text-n-slate-12">
              {{ $t('JRC_CAMPAIGNS.TITLE') }}
            </h1>
            <span
              class="rounded-full bg-n-brand/10 px-2 py-1 text-xs font-medium text-n-brand"
            >
              {{ $t('JRC_CAMPAIGNS.BRAND_BADGE') }}
            </span>
          </div>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ $t('JRC_CAMPAIGNS.SUBTITLE') }}
          </p>
        </div>
        <button
          v-if="activeTab === 'dispatches'"
          type="button"
          class="flex items-center gap-2 rounded-xl bg-emerald-700 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-800"
          @click="openNew"
        >
          <span class="i-lucide-plus size-4" />
          {{ $t('JRC_CAMPAIGNS.NEW_CAMPAIGN') }}
        </button>
      </div>

      <div class="mb-5 flex flex-wrap gap-1 border-b border-n-weak">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          class="flex items-center gap-2 border-b-2 px-4 py-3 text-sm font-medium transition-colors"
          :class="
            activeTab === tab.key
              ? 'border-emerald-700 text-emerald-800 dark:border-emerald-400 dark:text-emerald-300'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = tab.key"
        >
          <span class="size-4" :class="[tab.icon]" />
          {{ tab.label }}
        </button>
      </div>

      <template v-if="activeTab === 'dispatches'">
        <section class="rounded-2xl border border-n-weak bg-n-background p-4">
          <div
            class="grid gap-3 md:grid-cols-2 xl:grid-cols-[220px_1fr_190px_auto_auto]"
          >
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.PERIOD') }}
              <select
                v-model="period"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="7">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_7_DAYS') }}
                </option>
                <option value="30">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_30_DAYS') }}
                </option>
                <option value="90">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_90_DAYS') }}
                </option>
                <option value="all">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_PERIOD') }}
                </option>
              </select>
            </label>
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.CAMPAIGN') }}
              <select
                v-model="campaignFilter"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_CAMPAIGNS') }}
                </option>
                <option
                  v-for="campaign in campaigns"
                  :key="campaign.id"
                  :value="campaign.id"
                >
                  {{ campaign.name }}
                </option>
              </select>
            </label>
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.CHANNEL') }}
              <select
                v-model="channelFilter"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_CHANNELS') }}
                </option>
                <option value="whatsapp">
                  {{ $t('JRC_CAMPAIGNS.CHANNEL_WHATSAPP') }}
                </option>
                <option value="email">
                  {{ $t('JRC_CAMPAIGNS.CHANNEL_EMAIL') }}
                </option>
              </select>
            </label>
            <button
              type="button"
              class="self-end rounded-xl border border-n-strong px-3 py-2.5 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
              @click="showAdvancedFilters = !showAdvancedFilters"
            >
              <span class="i-lucide-list-filter mr-2 inline-block size-4" />
              {{ $t('JRC_CAMPAIGNS.FILTERS.ADVANCED') }}
            </button>
            <button
              type="button"
              class="self-end rounded-xl border border-n-strong p-2.5 text-n-slate-12 hover:bg-n-alpha-2"
              :title="$t('JRC_CAMPAIGNS.REFRESH')"
              @click="fetchData"
            >
              <span
                class="i-lucide-refresh-cw size-5"
                :class="{ 'animate-spin': loading || analyticsLoading }"
              />
            </button>
          </div>
          <div
            v-if="showAdvancedFilters"
            class="mt-4 flex flex-wrap items-center gap-2 border-t border-n-weak pt-4"
          >
            <span class="mr-1 text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.STATUS') }}
            </span>
            <button
              v-for="option in statusOptions"
              :key="option.status"
              type="button"
              class="rounded-full border px-3 py-1.5 text-xs font-medium"
              :class="
                statusFilters.includes(option.status)
                  ? 'border-n-brand bg-n-brand/10 text-n-brand'
                  : 'border-n-weak text-n-slate-11'
              "
              @click="toggleStatus(option.status)"
            >
              {{ option.label }}
            </button>
          </div>
        </section>

        <section class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          <article
            v-for="metric in dashboardMetrics"
            :key="metric.key"
            class="min-w-0 rounded-2xl border border-n-weak bg-gradient-to-b to-n-background p-3 shadow-sm"
            :class="metric.cardClass"
          >
            <div
              class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold"
              :class="metric.iconClass"
            >
              <span class="size-4 shrink-0" :class="metric.icon" />
              {{ metric.label }}
            </div>
            <div
              class="mt-3 flex flex-wrap items-center justify-between gap-2 px-1"
            >
              <p class="m-0 text-3xl font-bold tracking-tight text-n-slate-12">
                {{ formatNumber(analytics.summary[metric.key]) }}
              </p>
              <span
                v-if="metric.key !== 'sent'"
                class="rounded-full px-2 py-1 text-sm font-semibold"
                :class="metric.iconClass"
              >
                {{ formatPercent(metricRate(metric.key)) }}%
              </span>
            </div>
            <p class="mb-0 mt-2 px-1 text-sm text-n-slate-11">
              {{ metricDescription(metric.key) }}
            </p>
          </article>
        </section>

        <section class="mt-4 grid gap-4 xl:grid-cols-12">
          <article
            class="rounded-2xl border border-n-weak bg-n-background p-5 shadow-sm xl:col-span-7"
          >
            <div class="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 class="font-semibold text-n-slate-12">
                  {{ $t('JRC_CAMPAIGNS.DASHBOARD.PERFORMANCE') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ $t('JRC_CAMPAIGNS.DASHBOARD.REAL_DATA') }}
                </p>
              </div>
              <span
                class="rounded-lg bg-n-alpha-2 px-2.5 py-1 text-xs text-n-slate-11"
              >
                {{ $t('JRC_CAMPAIGNS.DASHBOARD.GROUP_BY_DAY') }}
              </span>
            </div>
            <CampaignPerformanceChart
              v-if="analytics.series.length"
              :series="analytics.series"
              :labels="chartMetricLabels"
            />
            <div
              v-else
              class="flex h-72 items-center justify-center rounded-xl bg-n-alpha-1 text-sm text-n-slate-11"
            >
              {{ $t('JRC_CAMPAIGNS.DASHBOARD.NO_ANALYTICS') }}
            </div>
          </article>

          <article
            class="rounded-2xl border border-n-weak bg-n-background p-5 shadow-sm xl:col-span-5"
          >
            <h2 class="font-semibold text-n-slate-12">
              {{ $t('JRC_CAMPAIGNS.FUNNEL.TITLE') }}
            </h2>
            <div class="mt-5 space-y-4">
              <div v-for="item in funnel" :key="item.key">
                <div class="mb-1.5 flex items-end justify-between gap-2">
                  <span class="text-sm font-medium text-n-slate-11">
                    {{ item.label }}
                  </span>
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ formatNumber(item.value) }}
                    <small class="font-normal text-n-slate-11">
                      {{ formatPercent(item.percentage) }}%
                    </small>
                  </span>
                </div>
                <progress
                  :value="item.value"
                  :max="analytics.summary.sent || 1"
                  class="h-2.5 w-full appearance-none overflow-hidden rounded-full bg-n-alpha-2 [&::-webkit-progress-bar]:rounded-full [&::-webkit-progress-bar]:bg-n-alpha-2 [&::-webkit-progress-value]:rounded-full"
                  :class="barClass(item.key)"
                />
              </div>
            </div>
          </article>
        </section>

        <section class="mt-4 grid gap-4 xl:grid-cols-12">
          <article
            class="rounded-2xl border border-n-weak bg-n-background p-5 shadow-sm xl:col-span-3"
          >
            <h2 class="font-semibold text-n-slate-12">
              {{ $t('JRC_CAMPAIGNS.FAILURES.TITLE') }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FAILURES.SUBTITLE') }}
            </p>
            <div v-if="visibleFailureReasons.length" class="mt-5 space-y-4">
              <div v-for="reason in visibleFailureReasons" :key="reason.key">
                <div class="mb-1.5 flex justify-between gap-3 text-sm">
                  <span class="text-n-slate-11">
                    {{
                      $t(`JRC_CAMPAIGNS.FAILURES.${reason.key.toUpperCase()}`)
                    }}
                  </span>
                  <span class="font-semibold text-n-slate-12">
                    {{ formatNumber(reason.count) }}
                  </span>
                </div>
                <progress
                  :value="reason.count"
                  :max="failureTotal || 1"
                  class="h-2.5 w-full appearance-none overflow-hidden rounded-full bg-n-alpha-2 [&::-webkit-progress-bar]:rounded-full [&::-webkit-progress-bar]:bg-n-alpha-2 [&::-webkit-progress-value]:rounded-full"
                  :class="failureBarClass(reason.key)"
                />
              </div>
            </div>
            <div
              v-else
              class="mt-5 rounded-xl bg-n-alpha-1 p-5 text-center text-sm text-n-slate-11"
            >
              {{ $t('JRC_CAMPAIGNS.FAILURES.EMPTY') }}
            </div>
          </article>

          <article
            class="overflow-hidden rounded-2xl border border-n-weak bg-n-background shadow-sm xl:col-span-9"
          >
            <div
              class="flex items-center justify-between gap-3 border-b border-n-weak p-5"
            >
              <div>
                <h2 class="font-semibold text-n-slate-12">
                  {{ $t('JRC_CAMPAIGNS.DASHBOARD.CAMPAIGN_PERFORMANCE') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{
                    $t('JRC_CAMPAIGNS.DASHBOARD.CAMPAIGN_COUNT', {
                      count: filteredCampaigns.length,
                    })
                  }}
                </p>
              </div>
              <button
                type="button"
                class="flex items-center gap-2 rounded-xl border border-n-strong px-3 py-2 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2"
                @click="exportSelected"
              >
                <span class="i-lucide-download size-4" />
                {{ $t('JRC_CAMPAIGNS.EXPORT') }}
              </button>
            </div>
            <div class="overflow-x-auto">
              <div
                v-if="loading"
                class="p-10 text-center text-sm text-n-slate-11"
              >
                {{ $t('JRC_CAMPAIGNS.LOADING') }}
              </div>
              <div
                v-else-if="!filteredCampaigns.length"
                class="p-12 text-center text-sm text-n-slate-11"
              >
                {{ $t('JRC_CAMPAIGNS.EMPTY_FILTERED') }}
              </div>
              <table v-else class="w-full min-w-[760px] text-left text-sm">
                <thead class="bg-n-teal-2/60 text-xs text-n-slate-12">
                  <tr>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.TABLE.NAME') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.TABLE.CHANNEL') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.KPIS.SENT') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.KPIS.DELIVERED') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.KPIS.READ') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.KPIS.REPLIES') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.TABLE.FAILURES') }}
                    </th>
                    <th class="px-3 py-3">
                      {{ $t('JRC_CAMPAIGNS.TABLE.STATUS') }}
                    </th>
                    <th class="px-4 py-3 text-right">
                      {{ $t('JRC_CAMPAIGNS.TABLE.ACTIONS') }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="campaign in filteredCampaigns"
                    :key="campaign.id"
                    class="border-t border-n-weak hover:bg-n-alpha-1"
                  >
                    <td class="px-3 py-4">
                      <button
                        type="button"
                        class="max-w-64 break-words text-left font-semibold text-n-slate-12 hover:text-n-brand"
                        @click="reportCampaign = campaign"
                      >
                        {{ campaign.name }}
                      </button>
                      <div class="mt-2 flex items-center gap-2">
                        <progress
                          :value="progress(campaign)"
                          max="100"
                          class="h-1.5 w-24 overflow-hidden rounded-full accent-n-brand"
                        />
                        <span class="text-[11px] text-n-slate-11">
                          {{ progress(campaign) }}%
                        </span>
                      </div>
                    </td>
                    <td class="px-3 py-4 text-n-slate-12">
                      <span
                        class="mr-1 inline-block size-3 text-n-teal-11"
                        :class="
                          campaign.delivery_channel === 'email'
                            ? 'i-lucide-mail'
                            : 'i-lucide-message-circle'
                        "
                      />
                      {{
                        $t(
                          campaign.delivery_channel === 'email'
                            ? 'JRC_CAMPAIGNS.CHANNEL_EMAIL'
                            : 'JRC_CAMPAIGNS.CHANNEL_WHATSAPP'
                        )
                      }}
                    </td>
                    <td class="px-3 py-4 text-n-slate-12">
                      {{ formatNumber(campaign.sent_count) }}
                    </td>
                    <td class="px-3 py-4 text-n-slate-12">
                      {{ formatNumber(campaign.delivered_count) }}
                    </td>
                    <td class="px-3 py-4 text-n-slate-12">
                      {{ formatNumber(campaign.read_count) }}
                    </td>
                    <td class="px-3 py-4 text-n-slate-12">
                      {{ formatNumber(campaign.replied_count) }}
                    </td>
                    <td
                      class="px-3 py-4"
                      :class="
                        campaign.failed_count
                          ? 'text-n-ruby-11'
                          : 'text-n-slate-12'
                      "
                    >
                      {{ formatNumber(campaign.failed_count) }}
                    </td>
                    <td class="px-3 py-4">
                      <span
                        class="inline-flex whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold"
                        :class="statusClass(campaign.status)"
                      >
                        {{ statusLabel(campaign.status) }}
                      </span>
                    </td>
                    <td class="px-3 py-4">
                      <div class="flex justify-end">
                        <CampaignActions
                          :campaign="campaign"
                          :deleting="deletingCampaignIds.includes(campaign.id)"
                          @review="reviewCampaign = campaign"
                          @launch="runAction(campaign, 'launch')"
                          @pause="runAction(campaign, 'pause')"
                          @resume="runAction(campaign, 'resume')"
                          @cancel="runAction(campaign, 'cancel')"
                          @edit="openEdit(campaign)"
                          @report="reportCampaign = campaign"
                          @duplicate="duplicateCampaign(campaign)"
                          @delete="deleteCampaign(campaign)"
                        />
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>
        </section>
      </template>

      <SanitizedLists
        v-else-if="activeTab === 'sanitize'"
        :lists="metadata.sanitized_lists"
        @changed="fetchData"
        @use-list="openFromList"
      />
      <BlacklistPanel v-else-if="activeTab === 'blacklist'" />
      <template v-else>
        <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-2xl font-semibold text-n-slate-12">
              {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.TITLE') }}
            </h2>
            <p class="mb-0 mt-1 text-sm text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.SUBTITLE') }}
            </p>
          </div>
          <button
            type="button"
            class="flex items-center gap-2 rounded-xl border border-n-teal-7 bg-n-background px-4 py-2.5 text-sm font-semibold text-n-teal-11 hover:bg-n-teal-2"
            @click="exportSelected"
          >
            <span class="i-lucide-download size-4" />
            {{ $t('JRC_CAMPAIGNS.EXPORT') }}
          </button>
        </div>
        <section class="rounded-2xl border border-n-weak bg-n-background p-4">
          <div
            class="grid gap-3 md:grid-cols-2 xl:grid-cols-[220px_1fr_190px_auto_auto]"
          >
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.PERIOD') }}
              <select
                v-model="period"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="7">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_7_DAYS') }}
                </option>
                <option value="30">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_30_DAYS') }}
                </option>
                <option value="90">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.LAST_90_DAYS') }}
                </option>
                <option value="all">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_PERIOD') }}
                </option>
              </select>
            </label>
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.CAMPAIGN') }}
              <select
                v-model="campaignFilter"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_CAMPAIGNS') }}
                </option>
                <option
                  v-for="campaign in campaigns"
                  :key="campaign.id"
                  :value="campaign.id"
                >
                  {{ campaign.name }}
                </option>
              </select>
            </label>
            <label class="text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.CHANNEL') }}
              <select
                v-model="channelFilter"
                class="mt-1.5 w-full rounded-xl border border-n-weak bg-n-background px-3 py-2.5 text-sm text-n-slate-12"
              >
                <option value="">
                  {{ $t('JRC_CAMPAIGNS.FILTERS.ALL_CHANNELS') }}
                </option>
                <option value="whatsapp">
                  {{ $t('JRC_CAMPAIGNS.CHANNEL_WHATSAPP') }}
                </option>
                <option value="email">
                  {{ $t('JRC_CAMPAIGNS.CHANNEL_EMAIL') }}
                </option>
              </select>
            </label>
            <button
              type="button"
              class="self-end rounded-xl border border-n-strong px-3 py-2.5 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
              @click="showAdvancedFilters = !showAdvancedFilters"
            >
              <span class="i-lucide-list-filter mr-2 inline-block size-4" />
              {{ $t('JRC_CAMPAIGNS.FILTERS.ADVANCED') }}
            </button>
            <button
              type="button"
              class="self-end rounded-xl border border-n-strong p-2.5 text-n-slate-12 hover:bg-n-alpha-2"
              :title="$t('JRC_CAMPAIGNS.REFRESH')"
              @click="fetchData"
            >
              <span
                class="i-lucide-refresh-cw size-5"
                :class="{ 'animate-spin': loading || analyticsLoading }"
              />
            </button>
          </div>
          <div
            v-if="showAdvancedFilters"
            class="mt-4 flex flex-wrap items-center gap-2 border-t border-n-weak pt-4"
          >
            <span class="mr-1 text-sm font-medium text-n-slate-11">
              {{ $t('JRC_CAMPAIGNS.FILTERS.STATUS') }}
            </span>
            <button
              v-for="option in statusOptions"
              :key="option.status"
              type="button"
              class="rounded-full border px-3 py-1.5 text-xs font-medium"
              :class="
                statusFilters.includes(option.status)
                  ? 'border-n-brand bg-n-brand/10 text-n-brand'
                  : 'border-n-weak text-n-slate-11'
              "
              @click="toggleStatus(option.status)"
            >
              {{ option.label }}
            </button>
          </div>
        </section>

        <div class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          <article
            v-for="metric in dashboardMetrics"
            :key="metric.key"
            class="min-w-0 rounded-xl border border-n-weak bg-n-background p-3 shadow-sm"
          >
            <div
              class="flex flex-wrap items-center gap-3 rounded-lg p-3"
              :class="metric.iconClass"
            >
              <span class="size-6 shrink-0" :class="metric.icon" />
              <div class="min-w-0 flex-1">
                <p class="m-0 text-sm font-medium">{{ metric.label }}</p>
                <p class="m-0 mt-1 text-2xl font-bold">
                  {{ formatNumber(analytics.summary[metric.key]) }}
                </p>
              </div>
              <span v-if="metric.key !== 'sent'" class="text-sm font-semibold">
                {{ formatPercent(metricRate(metric.key)) }}%
              </span>
            </div>
          </article>
        </div>
        <section
          class="mt-5 overflow-hidden rounded-2xl border border-n-weak bg-n-background shadow-sm"
        >
          <div class="border-b border-n-weak px-4 py-4 sm:px-5">
            <h3 class="text-lg font-semibold">
              {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.RESULTS') }}
            </h3>
            <p class="m-0 mt-1 text-sm text-n-slate-11">
              {{
                $t('JRC_CAMPAIGNS.DASHBOARD.CAMPAIGN_COUNT', {
                  count: filteredCampaigns.length,
                })
              }}
            </p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[1000px] text-left text-sm">
              <thead class="bg-n-teal-2 text-n-slate-12">
                <tr>
                  <th class="px-4 py-3">
                    {{ $t('JRC_CAMPAIGNS.REPORTS.CAMPAIGN') }}
                  </th>
                  <th class="px-3 py-3">
                    {{ $t('JRC_CAMPAIGNS.TABLE.CHANNEL') }}
                  </th>
                  <th class="px-3 py-3">
                    {{ $t('JRC_CAMPAIGNS.TABLE.CREATED') }}
                  </th>
                  <th class="px-3 py-3">
                    {{ $t('JRC_CAMPAIGNS.TABLE.STATUS') }}
                  </th>
                  <th
                    v-for="metric in dashboardMetrics"
                    :key="metric.key"
                    class="px-3 py-3 text-right"
                  >
                    {{ metric.label }}
                  </th>
                  <th class="px-4 py-3 text-right">
                    {{ $t('JRC_CAMPAIGNS.TABLE.ACTIONS') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="campaign in filteredCampaigns"
                  :key="campaign.id"
                  class="border-t border-n-weak hover:bg-n-teal-2/50"
                >
                  <td class="px-4 py-3 font-semibold">
                    <button
                      type="button"
                      class="max-w-64 break-words text-left hover:text-n-teal-11"
                      @click="reportCampaign = campaign"
                    >
                      {{ campaign.name }}
                    </button>
                  </td>
                  <td class="px-3 py-3">
                    <span class="flex items-center gap-2">
                      <span
                        class="size-4 shrink-0 text-n-teal-11"
                        :class="
                          campaign.delivery_channel === 'email'
                            ? 'i-lucide-mail'
                            : 'i-lucide-message-circle'
                        "
                      />
                      {{
                        $t(
                          campaign.delivery_channel === 'email'
                            ? 'JRC_CAMPAIGNS.CHANNEL_EMAIL'
                            : 'JRC_CAMPAIGNS.CHANNEL_WHATSAPP'
                        )
                      }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-n-slate-11">
                    {{
                      formatDate(
                        campaign.created_at,
                        campaign.sending_window?.timezone || 'UTC'
                      )
                    }}
                  </td>
                  <td class="px-3 py-3">
                    <span
                      class="inline-flex whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold"
                      :class="statusClass(campaign.status)"
                    >
                      {{ statusLabel(campaign.status) }}
                    </span>
                  </td>
                  <td
                    v-for="metric in dashboardMetrics"
                    :key="metric.key"
                    class="px-3 py-3 text-right tabular-nums"
                  >
                    {{ formatNumber(campaign[`${metric.key}_count`]) }}
                  </td>
                  <td class="px-4 py-3 text-right">
                    <button
                      type="button"
                      class="inline-flex items-center gap-2 whitespace-nowrap rounded-lg border border-n-teal-7 px-3 py-2 font-semibold text-n-teal-11 hover:bg-n-teal-2"
                      @click="reportCampaign = campaign"
                    >
                      <span
                        class="i-lucide-chart-no-axes-column-increasing size-4"
                      />
                      {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.VIEW') }}
                    </button>
                  </td>
                </tr>
                <tr v-if="!filteredCampaigns.length">
                  <td colspan="10" class="p-8 text-center text-n-slate-11">
                    {{ $t('JRC_CAMPAIGNS.EMPTY_FILTERED') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
        <div
          class="mt-4 flex items-center gap-3 rounded-xl border border-n-weak bg-n-background p-4"
        >
          <span
            class="i-lucide-chart-no-axes-column-increasing size-8 shrink-0 rounded-lg bg-n-teal-3 p-2 text-n-teal-11"
          />
          <p class="m-0 text-sm text-n-slate-11">
            {{ $t('JRC_CAMPAIGNS.REPORT_LAYOUT.DETAIL_HINT') }}
          </p>
        </div>
      </template>
    </div>

    <CampaignWizard
      v-if="showWizard"
      :campaign="editingCampaign"
      :metadata="metadata"
      :initial-sanitized-list-id="initialListId"
      @close="closeWizard"
      @saved="saved"
      @review-requested="reviewSavedCampaign"
      @refresh-senders="refreshSenders"
    />
    <CampaignReport
      v-if="reportCampaign"
      :campaign="reportCampaign"
      @close="
        reportCampaign = null;
        fetchData();
      "
    />
    <CampaignApproval
      v-if="reviewCampaign"
      :campaign="reviewCampaign"
      @close="reviewCampaign = null"
      @approved="
        reviewCampaign = null;
        fetchData();
      "
    />
  </div>
</template>
