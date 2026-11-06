<script setup>
import { ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { leadsAPI } from 'dashboard/api/crm';
const props = defineProps({ filters: { type: Object, required: true } });
const route = useRoute();
const store = useStore();
const { t } = useI18n();
const leads = ref([]);
const error = ref(false);
const loading = ref(false);
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
    class="mx-4 mt-4 rounded-2xl border border-n-weak bg-n-solid-2 p-4 sm:mx-6"
    :aria-label="t('CRM.FUNNEL.LEADS_TITLE')"
  >
    <h3 class="font-semibold text-n-slate-12">
      {{ t('CRM.FUNNEL.LEADS_TITLE') }}
    </h3>
    <p class="mt-1 text-xs text-n-slate-11">{{ t('CRM.FUNNEL.LEADS_HELP') }}</p>
    <p v-if="loading" role="status" class="mt-3 text-sm text-n-slate-11">
      {{ t('CRM.FUNNEL.LEADS_LOADING') }}
    </p>
    <p v-else-if="error" role="alert" class="mt-3 text-sm text-n-ruby-11">
      {{ t('CRM.FUNNEL.LEADS_ERROR') }}
      <button class="underline" @click="load">
        {{ t('CRM.FUNNEL.RETRY') }}
      </button>
    </p>
    <div v-else class="mt-3 grid gap-3 md:grid-cols-3">
      <article
        v-for="status in ['new', 'in_contact', 'qualified']"
        :key="status"
        class="min-w-0 rounded-xl bg-n-alpha-1 p-3"
      >
        <h4
          class="flex justify-between gap-2 text-sm font-semibold text-n-slate-12"
        >
          {{ t(`CRM.COMMERCIAL_SUMMARY.LEAD_${status.toUpperCase()}`) }}
          <span>{{ leads.filter(l => l.status === status).length }}</span>
        </h4>
        <ul class="mt-2 max-h-44 space-y-2 overflow-y-auto">
          <li
            v-for="lead in leads.filter(l => l.status === status)"
            :key="lead.id"
          >
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
  </section>
</template>
