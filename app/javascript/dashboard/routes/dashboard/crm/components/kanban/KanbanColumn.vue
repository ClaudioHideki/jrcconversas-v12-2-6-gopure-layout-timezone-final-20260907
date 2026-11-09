<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import KanbanCard from './KanbanCard.vue';
import FunnelRecordCard from './FunnelRecordCard.vue';
import CrmValueDisplay from '../shared/CrmValueDisplay.vue';

const props = defineProps({
  stage: { type: Object, required: true },
  deals: { type: Array, required: true },
  showPipeline: { type: Boolean, default: false },
  leads: { type: Array, default: () => [] },
  proposals: { type: Array, default: () => [] },
});

defineEmits(['dragStart', 'dragEnd', 'dragOver', 'drop']);

const dealCount = computed(() => props.deals.length);
const { t } = useI18n();
const recordCount = computed(
  () => dealCount.value + props.leads.length + props.proposals.length
);
const financialSum = computed(() =>
  props.deals.reduce((sum, deal) => sum + (deal.value_cents || 0), 0)
);
const weightedSum = computed(() =>
  props.deals.reduce(
    (sum, deal) =>
      sum + ((deal.value_cents || 0) * (props.stage.probability ?? 100)) / 100,
    0
  )
);
const overdueCount = computed(
  () =>
    props.deals.filter(deal => deal.overdue || deal.next_activity?.is_overdue)
      .length
);
const stageAccent = computed(() => {
  if (props.stage.is_won) return 'bg-n-teal-9';
  if (props.stage.is_lost) return 'bg-n-ruby-9';
  if (Number(props.stage.probability) >= 70) return 'bg-n-blue-9';
  if (Number(props.stage.probability) >= 40) return 'bg-n-iris-9';
  return 'bg-n-amber-9';
});
</script>

<template>
  <div
    class="flex min-w-[320px] max-w-[320px] flex-col overflow-hidden rounded-2xl border border-n-weak bg-n-alpha-1 shadow-sm"
    @dragover="!stage.virtual && $emit('dragOver', $event)"
    @drop="!stage.virtual && $emit('drop', $event)"
  >
    <div class="shrink-0 border-b border-n-weak bg-n-solid-2 p-3">
      <div class="-mx-3 -mt-3 mb-2 h-1" :class="stageAccent" />
      <div class="mb-1 flex items-center justify-between gap-2">
        <h3
          class="font-bold text-n-slate-12 text-sm truncate"
          :title="stage.name"
        >
          {{ stage.name }}
        </h3>
        <span
          class="rounded-full bg-n-alpha-3 px-2.5 py-1 text-xs font-bold text-n-slate-11"
          >{{ recordCount }}</span
        >
      </div>
      <p
        v-if="showPipeline && stage.pipeline_name"
        class="mb-1 truncate text-xs text-n-slate-11"
        :title="stage.pipeline_name"
      >
        {{ stage.pipeline_name }}
      </p>
      <p
        v-if="leads.length || proposals.length"
        class="mb-2 text-xs text-n-slate-11"
      >
        {{ t('CRM.FUNNEL.DEALS_COUNT', { count: dealCount }) }}
        <span v-if="leads.length">
          · {{ t('CRM.FUNNEL.LEADS_COUNT', { count: leads.length }) }}</span
        >
        <span v-if="proposals.length">
          ·
          {{
            t('CRM.FUNNEL.PROPOSALS_COUNT', { count: proposals.length })
          }}</span
        >
      </p>
      <div class="text-xs text-n-slate-10 flex flex-col gap-1">
        <div class="flex justify-between">
          <span>{{
            leads.length || proposals.length
              ? t('CRM.FUNNEL.DEALS_VALUE')
              : 'Total:'
          }}</span>
          <CrmValueDisplay
            :cents="financialSum"
            class="font-medium text-n-slate-11"
          />
        </div>
        <div class="flex justify-between">
          <span>Ponderado:</span>
          <CrmValueDisplay
            :cents="weightedSum"
            class="font-medium text-n-slate-11"
          />
        </div>
        <div
          v-if="overdueCount > 0"
          class="flex justify-between text-n-ruby-11 mt-1 font-medium"
        >
          <span>Atrasados:</span>
          <span>{{ overdueCount }}</span>
        </div>
      </div>
    </div>

    <div class="min-h-0 flex-1 overflow-y-auto p-3">
      <FunnelRecordCard
        v-for="lead in leads"
        :key="`lead-${lead.id}`"
        :record="lead"
        kind="lead"
      />
      <FunnelRecordCard
        v-for="proposal in proposals"
        :key="`proposal-${proposal.id}`"
        :record="proposal"
        kind="proposal"
      />
      <KanbanCard
        v-for="deal in deals"
        :key="deal.id"
        :deal="deal"
        draggable="true"
        @dragstart="$emit('dragStart', $event, deal)"
        @dragend="$emit('dragEnd', $event)"
      />
      <div
        v-if="!recordCount"
        class="mt-2 rounded-xl border-2 border-dashed border-n-weak bg-n-solid-2 p-6 text-center text-xs text-n-slate-9"
      >
        Nenhum negócio nesta etapa
      </div>
    </div>
  </div>
</template>
