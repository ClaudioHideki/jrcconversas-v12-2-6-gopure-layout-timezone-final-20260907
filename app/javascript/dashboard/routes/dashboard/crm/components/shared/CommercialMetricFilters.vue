<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';

const props = defineProps({
  initialFilters: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['change']);
const expanded = ref(
  Boolean(
    props.initialFilters.owner_id ||
      props.initialFilters.pipeline_id ||
      props.initialFilters.start_date ||
      props.initialFilters.end_date ||
      (props.initialFilters.period && props.initialFilters.period !== 'all')
  )
);
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const filters = ref({
  period: 'all',
  owner_id: '',
  pipeline_id: '',
  start_date: '',
  end_date: '',
  ...props.initialFilters,
});
const activeFilterCount = computed(
  () =>
    [
      isAdmin.value && filters.value.owner_id,
      filters.value.pipeline_id,
      filters.value.period !== 'all',
    ].filter(Boolean).length
);
const pipelines = computed(
  () => store.getters['jrcCrm/pipelines/allPipelines'] || []
);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const apply = () => {
  const { period, owner_id, pipeline_id, start_date, end_date } = filters.value;
  emit('change', {
    period,
    pipeline_id: pipeline_id || undefined,
    owner_id: isAdmin.value ? owner_id || undefined : undefined,
    ...(period === 'all' ? {} : { start_date, end_date }),
  });
};
onMounted(() => {
  store.dispatch('jrcCrm/pipelines/fetchPipelines');
  if (isAdmin.value) store.dispatch('agents/get');
  apply();
});
</script>

<template>
  <form
    class="rounded-xl border border-n-weak bg-n-solid-2 p-2 text-n-slate-12"
    :aria-label="t('CRM.METRICS.FILTERS')"
    @submit.prevent="apply"
  >
    <details :open="expanded" @toggle="expanded = $event.target.open">
      <summary
        class="cursor-pointer py-1 text-sm font-semibold text-n-slate-12"
      >
        {{ t('CRM.METRICS.FILTERS') }}
        <span
          v-if="activeFilterCount"
          class="ml-1 rounded bg-n-blue-3 px-1 text-xs text-n-blue-11"
          :aria-label="
            t('CRM.FUNNEL.ACTIVE_FILTERS', { count: activeFilterCount })
          "
          >{{ activeFilterCount }}</span
        >
        <span class="ml-2 text-xs font-normal text-n-slate-11"
          >{{
            filters.pipeline_id
              ? pipelines.find(
                  row => String(row.id) === String(filters.pipeline_id)
                )?.name
              : t('CRM.METRICS.ALL_PIPELINES')
          }}
          ·
          {{
            filters.period === 'all'
              ? t('CRM.METRICS.ALL_TIME')
              : t('CRM.METRICS.CUSTOM')
          }}</span
        >
      </summary>
      <div class="flex flex-wrap items-end gap-2">
        <label v-if="isAdmin" class="min-w-44 flex-1 text-xs">
          {{ t('CRM.METRICS.OWNER') }}
          <select
            v-model="filters.owner_id"
            class="!mb-0 mt-1 h-9 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3"
          >
            <option value="">{{ t('CRM.METRICS.ALL_OWNERS') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label class="min-w-44 flex-1 text-xs"
          >{{ t('CRM.METRICS.PIPELINE') }}
          <select
            v-model="filters.pipeline_id"
            class="!mb-0 mt-1 h-9 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3"
          >
            <option value="">{{ t('CRM.METRICS.ALL_PIPELINES') }}</option>
            <option
              v-for="pipeline in pipelines"
              :key="pipeline.id"
              :value="pipeline.id"
            >
              {{ pipeline.name }}
            </option>
          </select>
        </label>
        <label class="min-w-44 flex-1 text-xs"
          >{{ t('CRM.METRICS.PERIOD') }}
          <select
            v-model="filters.period"
            class="!mb-0 mt-1 h-9 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3"
          >
            <option value="all">{{ t('CRM.METRICS.ALL_TIME') }}</option>
            <option value="custom">{{ t('CRM.METRICS.CUSTOM') }}</option>
          </select>
        </label>
        <template v-if="filters.period !== 'all'">
          <label class="text-sm"
            >{{ t('CRM.METRICS.START')
            }}<input
              v-model="filters.start_date"
              type="date"
              required
              :max="filters.end_date || undefined"
              class="!mb-0 mt-1 block h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3"
          /></label>
          <label class="text-sm"
            >{{ t('CRM.METRICS.END')
            }}<input
              v-model="filters.end_date"
              type="date"
              required
              :min="filters.start_date || undefined"
              class="!mb-0 mt-1 block h-9 rounded-lg border border-n-weak bg-n-solid-2 px-3"
          /></label>
        </template>
        <button
          type="submit"
          class="min-h-9 rounded-lg bg-n-brand px-4 py-2 font-semibold text-white"
        >
          {{ t('CRM.METRICS.APPLY') }}
        </button>
      </div>
      <p class="mb-0 mt-2 text-xs text-n-slate-11">
        {{ t('CRM.METRICS.SCOPE_HELP') }}
      </p>
    </details>
  </form>
</template>
