<script setup>
import { ref, watch, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';
const emit = defineEmits(['completed']);
const { t } = useI18n();
const { isAdmin } = useAdmin();
const route = useRoute();
const dialog = ref(null);
const orders = ref([]);
const reason = ref('');
const plan = ref(null);
const confirmed = ref(false);
const confirmation = ref('');
const busy = ref(false);
const error = ref('');
const result = ref(null);
const orderNumbers = ids =>
  orders.value
    .filter(order => ids.includes(order.id))
    .map(order => order.order_number)
    .join(', ');
let generation = 0;
const clearPlan = () => {
  plan.value = null;
  confirmation.value = '';
  confirmed.value = false;
};
watch(reason, clearPlan);
watch(
  () => route.params.accountId,
  () => {
    generation += 1;
    clearPlan();
    dialog.value?.close();
  }
);
const open = rows => {
  if (!isAdmin.value || busy.value) return;
  generation += 1;
  orders.value = rows;
  reason.value = '';
  clearPlan();
  error.value = '';
  result.value = null;
  dialog.value.open();
};
const loadPreview = async () => {
  if (busy.value || !isAdmin.value || reason.value.trim().length < 3) return;
  generation += 1;
  const current = generation;
  busy.value = true;
  error.value = '';
  clearPlan();
  try {
    const { data } = await salesOrdersAPI.deletionPreview({
      ids: orders.value.map(r => r.id),
      reason: reason.value,
    });
    if (current === generation) plan.value = data;
  } catch (e) {
    if (current === generation)
      error.value =
        e.response?.data?.errors?.join(' ') || t('CRM.ORDER_DELETION.ERROR');
  } finally {
    busy.value = false;
  }
};
const canConfirm = computed(
  () =>
    isAdmin.value &&
    plan.value &&
    !plan.value.blocked &&
    !busy.value &&
    confirmed.value &&
    confirmation.value === plan.value.confirmation &&
    !result.value
);
const execute = async () => {
  if (!canConfirm.value) return;
  const current = generation;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await salesOrdersAPI.deleteWithDependencies({
      ids: orders.value.map(r => r.id),
      reason: reason.value,
      confirmed: confirmed.value,
      confirmation: confirmation.value,
      preview_token: plan.value.token,
    });
    if (current !== generation) return;
    result.value = data;
    emit('completed', data);
  } catch (e) {
    if (current !== generation) return;
    error.value =
      e.response?.data?.errors?.join(' ') || t('CRM.ORDER_DELETION.ERROR');
    clearPlan();
  } finally {
    busy.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="3xl"
    :title="t('CRM.ORDER_DELETION.TITLE')"
    :description="t('CRM.ORDER_DELETION.HELP')"
    :show-confirm-button="false"
    :show-cancel-button="!busy"
    overflow-y-auto
    :dismissible="!busy"
    :close-on-click-outside="!busy"
  >
    <div class="space-y-4 text-sm text-n-slate-12">
      <ul>
        <li v-for="order in orders" :key="order.id" class="font-semibold">
          {{ order.order_number }}
        </li>
      </ul>
      <label class="block"
        >{{ t('CRM.ORDER_DELETION.REASON') }}
        <textarea
          v-model="reason"
          name="deletion_reason"
          :disabled="busy || !!result"
          maxlength="1000"
          rows="3"
          class="mt-2 w-full rounded-lg border border-n-weak bg-n-solid-2 p-3"
        />
      </label>
      <button
        v-if="!result"
        type="button"
        :disabled="busy || reason.trim().length < 3 || orders.length > 20"
        class="min-h-11 rounded-lg border border-n-brand px-4 py-2 font-semibold text-n-blue-11 disabled:opacity-50"
        @click="loadPreview"
      >
        {{ t('CRM.ORDER_DELETION.PREVIEW') }}
      </button>
      <section v-if="plan" aria-live="polite" class="space-y-3">
        <div class="flex flex-wrap gap-3">
          <span
            >{{ t('CRM.ORDER_DELETION.DELETE') }}:
            {{ plan.counts.delete || 0 }}</span
          >
          <span
            >{{ t('CRM.ORDER_DELETION.CANCEL') }}:
            {{ plan.counts.cancel || 0 }}</span
          >
          <span
            >{{ t('CRM.ORDER_DELETION.PRESERVE') }}:
            {{ plan.counts.preserve || 0 }}</span
          >
        </div>
        <ul v-if="plan.issues?.length" role="alert" class="text-n-ruby-11">
          <li v-for="issue in plan.issues" :key="issue">{{ issue }}</li>
        </ul>
        <div class="max-h-80 overflow-auto rounded-lg border border-n-weak">
          <article
            v-for="row in plan.rows"
            :key="`${row.type}:${row.id}`"
            class="space-y-1 border-b border-n-weak p-3"
          >
            <strong>{{ row.label }} {{ row.reference }}</strong>
            <span
              class="ml-2 font-semibold"
              :class="
                row.action === 'delete' ? 'text-n-ruby-11' : 'text-n-amber-11'
              "
            >
              {{ t(`CRM.ORDER_DELETION.ACTION_${row.action.toUpperCase()}`) }}
            </span>
            <p v-if="row.status">{{ row.status }}</p>
            <p>{{ row.reason }}</p>
          </article>
        </div>
        <p
          v-if="plan.cancellation_requests?.length"
          class="rounded-lg bg-n-amber-2 p-3"
        >
          {{ t('CRM.ORDER_DELETION.CANCELLATION_REVIEW') }}
          {{ plan.cancellation_requests.join(', ') }}
        </p>
        <template v-if="!result">
          <label class="block"
            >{{ t('CRM.ORDER_DELETION.TYPE_CONFIRMATION') }}
            <strong>{{ plan.confirmation }}</strong>
            <input
              v-model="confirmation"
              name="deletion_confirmation"
              :disabled="busy"
              autocomplete="off"
              class="mt-2 min-h-11 w-full rounded-lg border border-n-weak bg-n-solid-2 p-3"
            />
          </label>
          <label class="flex gap-2"
            ><input
              v-model="confirmed"
              name="deletion_confirmed"
              type="checkbox"
              :disabled="busy"
            />{{ t('CRM.ORDER_DELETION.CONFIRM_SCOPE') }}</label
          >
          <button
            type="button"
            :disabled="!canConfirm"
            class="min-h-11 rounded-lg bg-n-ruby-9 px-4 py-2 font-semibold text-white disabled:opacity-50"
            @click="execute"
          >
            {{ t('CRM.ORDER_DELETION.EXECUTE') }}
          </button>
        </template>
      </section>
      <section
        v-if="result"
        role="status"
        class="space-y-2 rounded-lg bg-n-teal-2 p-3"
      >
        <p>
          {{ t('CRM.ORDER_DELETION.DONE') }} {{ result.receipt_ids.join(', ') }}
        </p>
        <p v-if="result.removed_ids.length">
          {{ t('CRM.ORDER_DELETION.RESULT_REMOVED') }}
          {{ orderNumbers(result.removed_ids) }}
        </p>
        <p v-if="result.retained_ids.length">
          {{ t('CRM.ORDER_DELETION.RESULT_RETAINED') }}
          {{ orderNumbers(result.retained_ids) }}
        </p>
        <p v-if="result.cancellation_request_ids?.length">
          {{ t('CRM.ORDER_DELETION.RESULT_REQUESTS') }}
          {{ result.cancellation_request_ids.join(', ') }}
        </p>
      </section>
      <p v-if="error" role="alert" class="text-n-ruby-11">{{ error }}</p>
    </div>
  </Dialog>
</template>
