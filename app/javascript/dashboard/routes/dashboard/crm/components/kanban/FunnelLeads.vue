<script setup>
import { computed, ref, useId, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { leadsAPI } from 'dashboard/api/crm';
const props = defineProps({
  filters: { type: Object, required: true },
  qualifiedRecords: { type: Array, default: null },
  qualifiedLoading: { type: Boolean, default: false },
});
const route = useRoute();
const store = useStore();
const { t } = useI18n();
const leads = ref([]);
const error = ref(false);
const loading = ref(false);
const expanded = ref(false);
const contentId = useId();
const groups = computed(() =>
  [
    { status: 'new', label: t('CRM.COMMERCIAL_SUMMARY.LEAD_NEW') },
    {
      status: 'in_contact',
      label: t('CRM.COMMERCIAL_SUMMARY.LEAD_IN_CONTACT'),
    },
    { status: 'qualified', label: t('CRM.COMMERCIAL_SUMMARY.LEAD_QUALIFIED') },
  ].map(group => ({
    ...group,
    leads:
      group.status === 'qualified' && props.qualifiedRecords !== null
        ? props.qualifiedRecords
        : leads.value.filter(lead => lead.status === group.status),
  }))
);
let generation = 0;
const load = async () => {
  generation += 1;
  const request = generation;
  leads.value = [];
  loading.value = true;
  error.value = false;
  try {
    const { pipeline_id: _pipeline, ...filters } = props.filters;
    const { data } = await leadsAPI.list({
      ...filters,
      funnel: true,
      period: filters.start_date || filters.end_date ? 'custom' : 'all',
    });
    if (request === generation) leads.value = data;
  } catch {
    if (request === generation) error.value = true;
  } finally {
    if (request === generation) loading.value = false;
  }
};
watch(
  () => [
    props.filters,
    route.params.accountId,
    store.getters.getCurrentUser?.id,
  ],
  load,
  { deep: true, immediate: true }
);
</script>

<template>
  <section
    class="mx-3 mt-2 shrink-0 rounded-xl border border-n-weak bg-n-solid-2 sm:mx-4"
    :aria-label="t('CRM.FUNNEL.LEADS_TITLE')"
  >
    <button
      type="button"
      class="flex w-full flex-wrap items-center gap-x-4 gap-y-1 rounded-xl px-3 py-2 text-left focus-visible:ring-2 focus-visible:ring-n-blue-8"
      :aria-expanded="expanded"
      :aria-controls="contentId"
      :aria-label="t('CRM.FUNNEL.LEADS_TOGGLE')"
      @click="expanded = !expanded"
    >
      <span class="text-sm font-semibold text-n-slate-12">
        {{ t('CRM.FUNNEL.LEADS_TITLE') }}
      </span>
      <span
        v-for="group in groups"
        :key="group.status"
        class="inline-flex items-center gap-1 text-xs text-n-slate-11"
      >
        {{ group.label }}
        <span class="rounded bg-n-alpha-2 px-1.5 font-semibold text-n-slate-12">
          {{
            loading || qualifiedLoading || error
              ? t('CRM.FUNNEL.COUNT_PENDING')
              : group.leads.length
          }}
        </span>
      </span>
      <i
        class="i-lucide-chevron-down ml-auto size-4 shrink-0 text-n-slate-11 transition-transform"
        :class="{ 'rotate-180': expanded }"
        aria-hidden="true"
      />
    </button>
    <p
      v-if="loading || qualifiedLoading"
      role="status"
      class="px-3 pb-2 text-sm text-n-slate-11"
    >
      {{ t('CRM.FUNNEL.LEADS_LOADING') }}
    </p>
    <p v-else-if="error" role="alert" class="px-3 pb-2 text-sm text-n-ruby-11">
      {{ t('CRM.FUNNEL.LEADS_ERROR') }}
      <button type="button" class="underline" @click="load">
        {{ t('CRM.FUNNEL.RETRY') }}
      </button>
    </p>
    <div v-if="expanded" :id="contentId" class="px-3 pb-3">
      <p class="mb-2 text-xs text-n-slate-11">
        {{ t('CRM.FUNNEL.LEADS_HELP') }}
      </p>
      <div
        v-if="!loading && !qualifiedLoading && !error"
        class="grid gap-2 md:grid-cols-3"
      >
        <article
          v-for="group in groups"
          :key="group.status"
          class="min-w-0 rounded-lg bg-n-alpha-1 p-2"
        >
          <h4
            class="flex justify-between gap-2 text-sm font-semibold text-n-slate-12"
          >
            {{ group.label }}
            <span>{{ group.leads.length }}</span>
          </h4>
          <ul class="mt-2 max-h-28 space-y-1 overflow-y-auto">
            <li v-for="lead in group.leads" :key="lead.id">
              <RouterLink
                :to="{ name: 'crm_leads', query: { leadId: lead.id } }"
                class="block rounded-lg border border-n-weak bg-n-solid-2 p-2 text-sm text-n-blue-11"
              >
                <span
                  class="mr-2 rounded bg-n-iris-3 px-1 text-xs text-n-iris-11"
                  >{{ t('CRM.FUNNEL.LEAD_TYPE') }}</span
                >{{ lead.name }}
              </RouterLink>
            </li>
          </ul>
        </article>
      </div>
    </div>
  </section>
</template>
