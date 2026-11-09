<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  projectCommercialBoard,
  resolveBoardTarget,
} from '../../helpers/funnelStages';
import {
  commercialFilterQuery,
  commercialFiltersFromQuery,
} from '../../helpers/commercialFilterQuery';
import { lostReasonsAPI } from 'dashboard/api/crm';
import FunnelLeads from './FunnelLeads.vue';
import KanbanColumn from './KanbanColumn.vue';
import KanbanFilters from './KanbanFilters.vue';
import { useDragAndDrop } from '../../composables/useDragAndDrop';
import CrmValueDisplay from '../shared/CrmValueDisplay.vue';

const store = useStore();
const { t } = useI18n();
const route = useRoute();
const { isAdmin } = useAdmin();
const lostReasons = ref([]);
const pendingLostMove = ref(null);
const lostReasonId = ref('');
const initializing = ref(true);
const actionError = ref(null);

// Filters state
const queryFilters = commercialFiltersFromQuery(route?.query);
const filters = ref({
  ...queryFilters,
  pipeline_id: queryFilters.pipeline_id || null,
  owner_id: queryFilters.owner_id || null,
  search: '',
});
const summaryLink = computed(() => ({
  name: 'crm_dashboard',
  query: commercialFilterQuery(filters.value),
}));

const loadKanbanData = async () => {
  if (!isAdmin.value) filters.value.owner_id = null;
  await store.dispatch('jrcCrm/deals/fetchKanbanData', filters.value);
};

// Load initial data
const initialize = async () => {
  initializing.value = true;
  try {
    await store.dispatch('jrcCrm/pipelines/fetchPipelines');
    if (store.getters['jrcCrm/pipelines/error']) return;
    await loadKanbanData();
  } finally {
    initializing.value = false;
  }
};
onMounted(() => {
  store.dispatch('agents/get');
  initialize();
});

// Columns = stages from selected pipeline
const funnelRecords = computed(
  () => store.getters['jrcCrm/deals/funnelRecords']
);
const columns = computed(() =>
  projectCommercialBoard(
    (store.getters['jrcCrm/deals/dealsByStage'] || []).map(
      ({ stage, deals }) => ({
        ...stage,
        deals,
        deals_count: deals.length,
        value_cents: deals.reduce(
          (sum, deal) => sum + Number(deal.value_cents || 0),
          0
        ),
      })
    ),
    funnelRecords.value,
    {
      negotiation: t('CRM.FUNNEL.NEGOTIATION'),
      qualification: t('CRM.FUNNEL.QUALIFICATION'),
      proposal_sent: t('CRM.FUNNEL.PROPOSAL_SENT'),
    }
  ).map(stage => ({
    stage,
    deals: stage.deals || [],
    leads: stage.leads,
    proposals: stage.proposals,
  }))
);
const loading = computed(
  () => initializing.value || store.getters['jrcCrm/deals/isLoading']
);
const error = computed(
  () =>
    store.getters['jrcCrm/pipelines/error'] ||
    store.getters['jrcCrm/deals/error']
);
const hasPipelines = computed(
  () => store.getters['jrcCrm/pipelines/allPipelines'].length > 0
);
const dealCount = computed(() =>
  columns.value.reduce((total, column) => total + column.deals.length, 0)
);
const recordCount = computed(() =>
  columns.value.reduce(
    (total, column) =>
      total +
      column.deals.length +
      column.leads.length +
      column.proposals.length,
    0
  )
);
const pipelineValue = computed(() =>
  columns.value.reduce(
    (total, column) =>
      total +
      column.deals.reduce(
        (columnTotal, deal) =>
          columnTotal +
          (deal.status === 'open' ? Number(deal.value_cents || 0) : 0),
        0
      ),
    0
  )
);

const performMove = async ({ dealId, fromStageId, toStageId, reasonId }) => {
  actionError.value = null;
  store.commit('jrcCrm/deals/UPDATE_DEAL_STAGE', {
    dealId,
    stageId: toStageId,
  });
  try {
    await store.dispatch('jrcCrm/deals/moveStage', {
      dealId,
      stageId: toStageId,
      lostReasonId: reasonId,
    });
    await loadKanbanData();
  } catch {
    actionError.value = t('CRM.FUNNEL.MOVE_ERROR');
    store.commit('jrcCrm/deals/ROLLBACK_DEAL_STAGE', {
      dealId,
      stageId: fromStageId,
    });
  }
};

const confirmLostMove = async () => {
  await performMove({ ...pendingLostMove.value, reasonId: lostReasonId.value });
  pendingLostMove.value = null;
  lostReasonId.value = '';
};

// Drag and drop
const { onDragStart, onDragOver, onDrop, onDragEnd } = useDragAndDrop({
  onMove: async ({ dealId, fromStageId, toStageId }) => {
    const column = columns.value.find(
      row => String(row.stage.id) === String(toStageId)
    )?.stage;
    const deal = store.getters['jrcCrm/deals/allDeals'].find(
      row => row.id === dealId
    );
    const stages = store.state.jrcCrm.deals.kanbanColumns;
    const targetStage =
      column && deal && resolveBoardTarget(column, deal, stages);
    if (!targetStage) {
      actionError.value = t('CRM.FUNNEL.TARGET_PIPELINE_MISSING');
      return;
    }
    if (String(targetStage.id) === String(fromStageId)) return;
    if (targetStage?.is_lost) {
      try {
        const { data } = await lostReasonsAPI.list();
        lostReasons.value = data;
      } catch {
        actionError.value = t('CRM.FUNNEL.REASONS_ERROR');
        return;
      }
      pendingLostMove.value = {
        dealId,
        fromStageId,
        toStageId: targetStage.id,
      };
      return;
    }
    await performMove({ dealId, fromStageId, toStageId: targetStage.id });
  },
});
</script>

<template>
  <div
    class="flex h-full min-h-0 min-w-0 flex-col overflow-y-auto bg-n-surface-1 lg:overflow-hidden"
  >
    <div class="shrink-0 space-y-2 px-3 pt-3 sm:px-4">
      <header class="flex flex-wrap items-center justify-between gap-2">
        <div class="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1">
          <h2
            class="text-lg font-bold text-n-slate-12"
            :title="t('CRM.FUNNEL.BOARD_HELP')"
          >
            {{ t('CRM.FUNNEL.TITLE') }}
          </h2>
          <span
            class="inline-flex items-center gap-1 text-xs font-semibold text-n-blue-11"
          >
            <i class="i-lucide-chart-no-axes-column-increasing size-3" />
            {{ dealCount }} {{ t('CRM.FUNNEL.DEAL_TYPE') }}
          </span>
          <span
            class="inline-flex items-center gap-1 text-xs font-semibold text-n-teal-11"
          >
            <i class="i-lucide-circle-dollar-sign size-3" />
            <CrmValueDisplay :cents="pipelineValue" />
            {{ t('CRM.FUNNEL.OPEN_VALUE') }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <RouterLink
            :to="summaryLink"
            class="rounded-lg border border-n-weak px-3 py-2 text-sm font-semibold text-n-slate-12"
          >
            {{ t('CRM.FUNNEL.SUMMARY_LINK') }}
          </RouterLink>
          <RouterLink
            :to="{ name: 'crm_deals', query: { new: '1' } }"
            class="rounded-lg bg-n-teal-9 px-3 py-2 text-sm font-semibold text-white shadow-sm"
          >
            <i
              class="i-lucide-plus mr-1 inline-block h-4 w-4 align-text-bottom"
            />
            {{ t('CRM.FUNNEL.NEW_OPPORTUNITY') }}
          </RouterLink>
        </div>
      </header>
      <div class="rounded-xl border border-n-weak bg-n-solid-2">
        <KanbanFilters v-model:filters="filters" @change="loadKanbanData" />
      </div>
    </div>
    <FunnelLeads
      v-if="!error"
      :filters="filters"
      :qualified-records="funnelRecords?.qualified_leads"
      :qualified-loading="loading"
    />
    <div
      v-if="loading"
      class="m-6 rounded-2xl border border-n-weak bg-n-solid-2 p-8 text-center text-n-slate-10 shadow-sm"
    >
      Carregando funil…
    </div>
    <div
      v-else-if="error"
      role="alert"
      class="m-6 rounded-2xl border border-n-ruby-6 bg-n-ruby-3 p-8 text-center text-n-ruby-11"
    >
      {{ error }}
      <button type="button" class="ml-3 underline" @click="initialize">
        {{ t('CRM.FUNNEL.RETRY') }}
      </button>
    </div>
    <div
      v-else-if="!columns.length"
      role="status"
      class="m-6 rounded-2xl border border-n-weak bg-n-solid-2 p-8 text-center text-n-slate-11"
    >
      {{
        hasPipelines ? t('CRM.FUNNEL.NO_STAGES') : t('CRM.FUNNEL.NO_PIPELINES')
      }}
    </div>
    <p
      v-else-if="!recordCount"
      role="status"
      class="mx-6 mt-4 text-sm text-n-slate-11"
    >
      {{ t('CRM.FUNNEL.NO_DEALS') }}
    </p>
    <p v-if="actionError" role="alert" class="mx-6 mt-4 text-sm text-n-ruby-11">
      {{ actionError }}
    </p>
    <div
      v-if="!loading && !error && columns.length"
      role="region"
      :aria-label="t('CRM.FUNNEL.DEAL_STAGES_TITLE')"
      tabindex="0"
      class="flex min-h-[320px] flex-1 gap-3 overflow-x-auto p-3 sm:px-4 lg:min-h-0"
    >
      <KanbanColumn
        v-for="column in columns"
        :key="column.stage.id"
        :stage="column.stage"
        :deals="column.deals"
        :leads="column.leads"
        :proposals="column.proposals"
        :show-pipeline="!filters.pipeline_id"
        @drag-start="onDragStart"
        @drag-end="onDragEnd"
        @drag-over="onDragOver"
        @drop="onDrop($event, column.stage.id)"
      />
    </div>
    <Teleport to="body">
      <div
        v-if="pendingLostMove"
        class="fixed inset-0 z-[80] flex items-center justify-center bg-black/40 p-4"
      >
        <div class="w-full max-w-md rounded-xl bg-n-solid-2 p-6 shadow-2xl">
          <h3 class="text-lg font-semibold text-n-slate-12">
            {{ t('CRM.LOSS.TITLE') }}
          </h3>
          <select
            v-model="lostReasonId"
            class="mt-4 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
          >
            <option disabled value="">{{ t('CRM.LOSS.SELECT') }}</option>
            <option
              v-for="reason in lostReasons"
              :key="reason.id"
              :value="reason.id"
            >
              {{ reason.name }}
            </option>
          </select>
          <div class="mt-5 flex justify-end gap-2">
            <button
              type="button"
              class="px-4 py-2 text-sm"
              @click="pendingLostMove = null"
            >
              {{ t('CRM.CANCEL') }}
            </button>
            <button
              type="button"
              :disabled="!lostReasonId"
              class="rounded-lg bg-n-ruby-9 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
              @click="confirmLostMove"
            >
              {{ t('CRM.LOSS.CONFIRM') }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
