<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import JrcCampaignsAPI from 'dashboard/api/jrcCampaigns';
import { useAlert } from 'dashboard/composables';
import CampaignReviewMessage from './CampaignReviewMessage.vue';

const props = defineProps({ campaign: { type: Object, required: true } });
const emit = defineEmits(['close', 'approved']);
const { t } = useI18n();
const review = ref(null);
const accepted = ref(false);
const saving = ref(false);
const errorMessage = ref('');
const audienceMatches = computed(() => {
  if (!review.value) return false;
  const count = review.value.review_snapshot?.recipients?.length;
  const expected = props.campaign.estimated_recipients;
  const confirmation = review.value.audience_config?.selection_confirmation;
  return (
    count > 0 &&
    (expected === undefined || Number(expected) === count) &&
    Number(review.value.estimated_recipients) === count &&
    (!confirmation || confirmation.count === count)
  );
});
const configuration = computed(
  () => review.value?.review_snapshot?.configuration || {}
);
const recipients = computed(
  () => review.value?.review_snapshot?.recipients || []
);
const inboxName = id =>
  review.value.campaign_inboxes.find(
    link => String(link.inbox_id) === String(id)
  )?.name || String(id);
const definitionsFor = inboxId =>
  (configuration.value.meta_templates || [])
    .filter(
      item => inboxId === undefined || String(item.inbox_id) === String(inboxId)
    )
    .flatMap(item => item.definitions || []);
const summary = computed(() => {
  if (!review.value) return [];
  const data = review.value;
  const window = data.sending_window || {};
  const schedule = data.scheduled_at
    ? new Date(data.scheduled_at).toLocaleString(undefined, {
        timeZone: window.timezone || 'UTC',
        timeZoneName: 'short',
      })
    : t('JRC_CAMPAIGNS.GOVERNANCE.MANUAL');
  const recurrence = data.recurrence_config || {};
  const recurrenceKeys = {
    none: 'NONE',
    daily: 'DAILY',
    weekly: 'WEEKLY',
    monthly: 'MONTHLY',
  };
  const rotationKeys = {
    round_robin: 'ROUND_ROBIN',
    random: 'RANDOM',
    weighted: 'WEIGHTED',
    least_used: 'LEAST_USED',
    priority: 'PRIORITY',
  };
  const conversationKeys = {
    reply_only: 'REPLY_ONLY',
    pending: 'PENDING',
    open: 'OPEN',
  };
  const days = (window.days || [])
    .map(day => t(`JRC_CAMPAIGNS.DAYS.${day}`))
    .join(', ');
  const modeLabel = (value, keys) =>
    keys[value]
      ? t(`JRC_CAMPAIGNS.WIZARD.${keys[value]}`)
      : value || t('JRC_CAMPAIGNS.NOT_AVAILABLE');
  return [
    { key: 'SCHEDULE', value: schedule },
    {
      key: 'WINDOW',
      value: `${days} · ${window.start || '—'}–${window.end || '—'}`,
      note: window.timezone,
    },
    {
      key: 'INBOXES',
      value:
        data.campaign_inboxes.map(link => link.name).join(', ') ||
        data.inbox_id,
    },
    {
      key: 'INTERVAL',
      value:
        Number(data.delay_min_seconds) === 0 &&
        Number(data.delay_max_seconds) === 0
          ? t('JRC_CAMPAIGNS.REVIEW_LAYOUT.NO_INTERVAL')
          : t('JRC_CAMPAIGNS.GOVERNANCE.SECONDS', {
              min: data.delay_min_seconds,
              max: data.delay_max_seconds,
            }),
    },
    {
      key: 'RECURRENCE',
      value:
        recurrence.type === 'custom'
          ? t('JRC_CAMPAIGNS.REVIEW_LAYOUT.EVERY_DAYS', {
              count: recurrence.interval_days,
            })
          : modeLabel(recurrence.type || 'none', recurrenceKeys),
    },
    { key: 'ROTATION', value: modeLabel(data.rotation_mode, rotationKeys) },
    {
      key: 'CONVERSATION',
      value: modeLabel(data.conversation_mode, conversationKeys),
    },
  ];
});

onMounted(async () => {
  try {
    const { data } = await JrcCampaignsAPI.requestReview(props.campaign.id);
    review.value = data;
    if (!audienceMatches.value)
      errorMessage.value = t('JRC_CAMPAIGNS.GOVERNANCE.AUDIENCE_CHANGED');
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.errors?.join(', ') ||
      t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED');
  }
});

const approve = async () => {
  if (!accepted.value || !audienceMatches.value || saving.value) return;
  saving.value = true;
  try {
    await JrcCampaignsAPI.approve(
      props.campaign.id,
      review.value.review_digest
    );
    useAlert(t('JRC_CAMPAIGNS.GOVERNANCE.APPROVED'));
    emit('approved');
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.errors?.join(', ') ||
      t('JRC_CAMPAIGNS.ALERTS.ACTION_FAILED');
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-3 sm:p-6"
    role="dialog"
    aria-modal="true"
    :aria-label="t('JRC_CAMPAIGNS.GOVERNANCE.REVIEW')"
    @keydown.esc.stop="emit('close')"
  >
    <div
      class="flex max-h-full min-w-0 w-full max-w-5xl flex-col overflow-hidden rounded-2xl bg-n-background text-base text-n-slate-12 shadow-xl"
    >
      <header
        class="flex shrink-0 items-start justify-between gap-4 border-b border-n-weak px-5 py-4 sm:px-6"
      >
        <div class="min-w-0">
          <p class="mb-1 text-sm font-medium text-n-teal-11">
            {{ t('JRC_CAMPAIGNS.GOVERNANCE.REVIEW') }}
          </p>
          <h2 class="break-words text-2xl font-semibold">
            {{ campaign.name }}
          </h2>
        </div>
        <button
          type="button"
          class="flex shrink-0 items-center gap-2 rounded-lg border border-n-weak px-3 py-2 text-sm hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          <span class="i-lucide-x size-4" />
          {{ t('JRC_CAMPAIGNS.CLOSE') }}
        </button>
      </header>
      <div class="min-h-0 overflow-y-auto overscroll-contain p-5 sm:p-6">
        <p
          v-if="errorMessage"
          role="alert"
          class="mb-4 rounded-xl bg-n-ruby-3 p-4 text-n-ruby-11"
        >
          {{ errorMessage }}
        </p>
        <template v-if="review">
          <div class="mb-5 rounded-xl border border-n-teal-6 bg-n-teal-2 p-4">
            <p class="font-semibold">
              {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.CHECK_BEFORE_APPROVING') }}
            </p>
            <p class="mt-1 text-sm leading-6">
              {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.POLICY_SHORT') }}
            </p>
            <details class="mt-2 text-sm">
              <summary class="cursor-pointer font-medium">
                {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.POLICY_DETAILS') }}
              </summary>
              <p class="mt-2 leading-6">
                {{ t('JRC_CAMPAIGNS.GOVERNANCE.POLICY') }}
              </p>
            </details>
          </div>
          <p
            v-if="configuration.evolution_connectors?.length"
            class="mb-4 rounded-xl bg-n-amber-3 p-4 text-sm leading-6 text-n-amber-11"
            role="note"
          >
            {{ t('JRC_CAMPAIGNS.EVOLUTION.WARNING') }}
          </p>
          <p
            v-for="connector in configuration.evolution_connectors || []"
            :key="connector.inbox_id"
            class="mb-3 break-words text-sm font-medium"
          >
            {{ t('JRC_CAMPAIGNS.EVOLUTION.SENDER') }}
            {{ connector.sender_number }} ·
            {{ t('JRC_CAMPAIGNS.EVOLUTION.CONNECTOR_LABEL') }}
          </p>
          <section class="mb-6">
            <h3 class="mb-3 text-lg font-semibold">
              {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.SUMMARY') }}
            </h3>
            <dl class="m-0 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <div
                v-for="item in summary"
                :key="item.key"
                class="min-w-0 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
              >
                <dt class="text-sm text-n-slate-11">
                  {{ t(`JRC_CAMPAIGNS.GOVERNANCE.${item.key}`) }}
                </dt>
                <dd class="m-0 mt-1 break-words font-medium">
                  {{ item.value }}
                </dd>
                <dd
                  v-if="item.note"
                  class="m-0 mt-1 break-words text-sm text-n-slate-11"
                >
                  {{ item.note }}
                </dd>
              </div>
            </dl>
          </section>
          <section class="mb-6">
            <h3 class="mb-3 text-lg font-semibold">
              {{ t('JRC_CAMPAIGNS.WIZARD.MESSAGES') }}
              <span class="ml-1 rounded-full bg-n-alpha-2 px-2 py-0.5 text-sm">
                {{ review.steps.length }}
              </span>
            </h3>
            <div class="space-y-4">
              <article
                v-for="(step, index) in review.steps"
                :key="step.id || index"
                class="min-w-0 rounded-xl border border-n-weak p-4"
              >
                <h4 class="mb-3 text-sm font-semibold text-n-slate-11">
                  {{
                    t('JRC_CAMPAIGNS.REVIEW_LAYOUT.MESSAGE_NUMBER', {
                      count: index + 1,
                    })
                  }}
                </h4>
                <CampaignReviewMessage
                  :step="step"
                  :definitions="definitionsFor()"
                />
                <div
                  v-for="(override, inboxId) in step.inbox_overrides"
                  :key="inboxId"
                  class="mt-4 min-w-0 border-t border-n-weak pt-4"
                >
                  <p class="mb-3 break-words text-sm font-semibold">
                    {{ t('JRC_CAMPAIGNS.GOVERNANCE.INBOXES') }}:
                    {{ inboxName(inboxId) }}
                  </p>
                  <CampaignReviewMessage
                    :step="{ ...step, ...override }"
                    :definitions="definitionsFor(inboxId)"
                  />
                </div>
              </article>
            </div>
          </section>
          <section>
            <div class="mb-3 flex items-center justify-between gap-3">
              <h3 class="text-lg font-semibold">
                {{ t('JRC_CAMPAIGNS.GOVERNANCE.AUDIENCE') }}
              </h3>
              <span
                class="rounded-full bg-n-teal-3 px-3 py-1 font-semibold text-n-teal-11"
              >
                {{ recipients.length }}
              </span>
            </div>
            <div
              class="max-h-64 overflow-y-auto rounded-xl border border-n-weak"
            >
              <div
                v-for="recipient in recipients"
                :key="
                  recipient.destination ||
                  recipient.email ||
                  recipient.phone_number
                "
                class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 border-b border-n-weak px-4 py-3 last:border-0"
              >
                <span
                  v-if="recipient.name"
                  class="min-w-0 break-words font-medium"
                >
                  {{ recipient.name }}
                </span>
                <span class="break-all text-sm text-n-slate-11">
                  {{
                    recipient.destination ||
                    recipient.email ||
                    recipient.phone_number
                  }}
                </span>
              </div>
              <p v-if="!recipients.length" class="p-4 text-sm">
                {{ t('JRC_CAMPAIGNS.GOVERNANCE.EMPTY_AUDIENCE') }}
              </p>
            </div>
          </section>
        </template>
        <p v-else-if="!errorMessage">{{ t('JRC_CAMPAIGNS.LOADING') }}</p>
      </div>
      <footer
        v-if="review"
        class="shrink-0 space-y-3 border-t border-n-weak bg-n-background px-5 py-4 sm:px-6"
      >
        <label class="flex items-start gap-3 text-sm leading-6">
          <input
            v-model="accepted"
            type="checkbox"
            class="mt-1 size-4 shrink-0"
          />
          <span>{{ t('JRC_CAMPAIGNS.GOVERNANCE.ATTEST') }}</span>
        </label>
        <div class="flex flex-wrap items-center justify-between gap-3">
          <p class="m-0 text-sm text-n-slate-11">
            {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.APPROVAL_ONLY') }}
          </p>
          <button
            type="button"
            class="w-full rounded-xl bg-n-brand px-5 py-3 font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40 sm:w-auto"
            :disabled="!accepted || !audienceMatches || saving"
            @click="approve"
          >
            {{ t('JRC_CAMPAIGNS.GOVERNANCE.APPROVE') }}
          </button>
        </div>
      </footer>
    </div>
  </div>
</template>
