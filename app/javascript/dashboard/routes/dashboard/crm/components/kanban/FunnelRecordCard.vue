<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CrmValueDisplay from '../shared/CrmValueDisplay.vue';

const props = defineProps({
  record: { type: Object, required: true },
  kind: {
    type: String,
    required: true,
    validator: value => ['lead', 'proposal'].includes(value),
  },
});
const { t } = useI18n();
const destination = computed(() =>
  props.kind === 'lead'
    ? { name: 'crm_leads', query: { leadId: props.record.id } }
    : { name: 'crm_proposals', query: { proposalId: props.record.id } }
);
const status = computed(
  () =>
    ({
      sent: t('CRM.INDICATORS.STATUS.SENT'),
      viewed: t('CRM.INDICATORS.STATUS.VIEWED'),
      accepted: t('CRM.INDICATORS.STATUS.ACCEPTED'),
      rejected: t('CRM.INDICATORS.STATUS.REJECTED'),
      canceled: t('CRM.INDICATORS.STATUS.CANCELED'),
      draft: t('CRM.INDICATORS.STATUS.DRAFT'),
      pending_approval: t('CRM.FUNNEL.PENDING_APPROVAL'),
    })[props.record.status]
);
</script>

<template>
  <RouterLink
    :to="destination"
    :draggable="false"
    class="mb-3 block rounded-xl border border-n-weak bg-n-solid-2 p-3 text-n-slate-12 shadow-sm hover:border-n-brand focus-visible:ring-2 focus-visible:ring-n-blue-8"
  >
    <div class="mb-2 flex flex-wrap items-center justify-between gap-2 text-xs">
      <span class="rounded bg-n-iris-3 px-1.5 py-0.5 text-n-iris-11">
        {{
          kind === 'lead'
            ? t('CRM.FUNNEL.LEAD_TYPE')
            : t('CRM.FUNNEL.PROPOSAL_TYPE')
        }}
      </span>
      <span v-if="kind === 'proposal'" class="font-semibold text-n-slate-11">{{
        status
      }}</span>
    </div>
    <strong class="block break-words text-sm">{{
      record.name || record.title
    }}</strong>
    <p v-if="kind === 'lead'" class="mt-1 text-xs text-n-slate-11">
      {{ t('CRM.FUNNEL.LEAD_WITHOUT_PIPELINE') }}
    </p>
    <template v-else>
      <p class="mt-1 text-xs text-n-slate-11">
        {{
          t('CRM.FUNNEL.PROPOSAL_REFERENCE', {
            number: record.proposal_number,
            version: record.version_number,
          })
        }}
      </p>
      <CrmValueDisplay
        :cents="record.total_cents"
        class="mt-2 block text-sm font-semibold"
      />
    </template>
  </RouterLink>
</template>
