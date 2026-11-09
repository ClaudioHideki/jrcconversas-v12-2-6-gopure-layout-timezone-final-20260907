<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, ref, useId } from 'vue';
import { useStore } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  filters: { type: Object, required: true },
});

const emit = defineEmits(['update:filters', 'change']);

const store = useStore();
const { isAdmin } = useAdmin();
const { t } = useI18n();
const expanded = ref(false);
const advancedId = useId();
const activeAdvancedCount = computed(
  () =>
    [
      isAdmin.value && props.filters.owner_id,
      props.filters.start_date,
      props.filters.end_date,
      props.filters.overdueOnly,
      props.filters.noNextActivity,
    ].filter(Boolean).length
);

const pipelines = computed(
  () => store.state.jrcCrm?.pipelines?.pipelines || []
);
const agents = computed(() => store.state.agents?.records || []);

const localFilters = computed({
  get: () => props.filters,
  set: val => emit('update:filters', val),
});

const onFilterChange = () => {
  emit('change');
};

const clearFilters = () => {
  localFilters.value = {
    pipeline_id: null,
    owner_id: null,
    search: '',
    overdueOnly: false,
    noNextActivity: false,
    start_date: '',
    end_date: '',
  };
  emit('change');
};
</script>

<template>
  <div class="bg-n-solid-2 p-2 [&_input]:!mb-0 [&_select]:!mb-0">
    <div class="flex flex-wrap items-center gap-2">
      <div class="min-w-[160px] flex-1">
        <div class="relative">
          <i
            class="i-lucide-search absolute left-3 top-1/2 transform -translate-y-1/2 text-n-slate-10"
          />
          <input
            v-model="localFilters.search"
            type="text"
            placeholder="Buscar negócios..."
            class="h-10 w-full rounded-xl border border-n-weak bg-n-solid-2 py-2 !pl-9 pr-3 text-sm focus:border-n-brand"
            @input="onFilterChange"
          />
        </div>
      </div>

      <div class="w-40 sm:w-48">
        <select
          v-model="localFilters.pipeline_id"
          class="h-10 w-full rounded-xl border border-n-weak bg-n-solid-2 px-3 text-sm"
          @change="onFilterChange"
        >
          <option :value="null">Todos os Funis</option>
          <option v-for="p in pipelines" :key="p.id" :value="p.id">
            {{ p.name }}
          </option>
        </select>
      </div>

      <button
        type="button"
        class="flex h-10 items-center gap-2 rounded-xl border border-n-weak px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-blue-8"
        :aria-expanded="expanded"
        :aria-controls="advancedId"
        :title="t('CRM.FUNNEL.ACTIVE_FILTERS', { count: activeAdvancedCount })"
        @click="expanded = !expanded"
      >
        <i class="i-lucide-sliders-horizontal size-4" aria-hidden="true" />
        {{ t('CRM.FUNNEL.FILTERS') }}
        <span
          v-if="activeAdvancedCount"
          class="rounded-full bg-n-blue-3 px-1.5 text-xs font-semibold text-n-blue-11"
          >{{ activeAdvancedCount }}</span
        >
        <i
          class="i-lucide-chevron-down size-3 transition-transform"
          :class="{ 'rotate-180': expanded }"
          aria-hidden="true"
        />
      </button>
      <button
        type="button"
        class="h-10 rounded-xl px-3 text-sm font-medium text-n-slate-11 hover:bg-n-alpha-2"
        @click="clearFilters"
      >
        Limpar Filtros
      </button>
    </div>

    <div
      v-show="expanded"
      :id="advancedId"
      class="mt-2 flex flex-wrap items-end gap-2 border-t border-n-weak pt-2"
    >
      <div v-if="isAdmin" class="w-48">
        <select
          v-model="localFilters.owner_id"
          class="h-10 w-full rounded-xl border border-n-weak bg-n-solid-2 px-3 text-sm"
          @change="onFilterChange"
        >
          <option :value="null">Todos os Responsáveis</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{ a.name }}
          </option>
        </select>
      </div>

      <label class="text-xs text-n-slate-11"
        >{{ t('CRM.METRICS.START') }}
        <input
          v-model="localFilters.start_date"
          type="date"
          :max="localFilters.end_date || undefined"
          class="mt-1 block h-10 rounded-xl border border-n-weak bg-n-solid-2 px-3"
          @change="onFilterChange"
        />
      </label>
      <label class="text-xs text-n-slate-11"
        >{{ t('CRM.METRICS.END') }}
        <input
          v-model="localFilters.end_date"
          type="date"
          :min="localFilters.start_date || undefined"
          class="mt-1 block h-10 rounded-xl border border-n-weak bg-n-solid-2 px-3"
          @change="onFilterChange"
        />
      </label>

      <div class="flex items-center gap-2">
        <label
          class="flex h-10 cursor-pointer items-center gap-2 rounded-xl border border-n-ruby-6 bg-n-ruby-3 px-3 text-sm font-medium text-n-ruby-11"
        >
          <input
            v-model="localFilters.overdueOnly"
            type="checkbox"
            class="rounded border-n-weak text-n-blue-11 focus:ring-blue-500"
            @change="onFilterChange"
          />
          Atrasados
        </label>
      </div>

      <div class="flex items-center gap-2">
        <label
          class="flex h-10 cursor-pointer items-center gap-2 rounded-xl border border-n-amber-6 bg-n-amber-3 px-3 text-sm font-medium text-n-amber-11"
        >
          <input
            v-model="localFilters.noNextActivity"
            type="checkbox"
            class="rounded border-n-weak text-n-blue-11 focus:ring-blue-500"
            @change="onFilterChange"
          />
          Sem próx. atividade
        </label>
      </div>
    </div>
  </div>
</template>
