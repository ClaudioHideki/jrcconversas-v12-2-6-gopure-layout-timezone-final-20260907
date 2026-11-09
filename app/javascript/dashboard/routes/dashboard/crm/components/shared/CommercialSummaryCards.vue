<script setup>
import { commercialSummaryCards } from './commercialSummaryCards';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmMetrics } from '../../composables/useCrmMetrics';
const props = defineProps({ summary: { type: Object, default: () => ({}) } });
const { t } = useI18n();
const { formatBRL } = useCrmMetrics();
const cards = computed(() =>
  commercialSummaryCards(props.summary || {}, t, formatBRL)
);
</script>

<template>
  <section
    class="grid grid-cols-2 gap-2 lg:grid-cols-3 xl:grid-cols-6"
    :aria-label="t('CRM.COMMERCIAL_SUMMARY.TITLE')"
  >
    <article
      v-for="card in cards"
      :key="card.key"
      class="min-w-0 rounded-2xl border border-n-weak bg-n-solid-2 p-3 shadow-sm"
    >
      <h3 class="text-xs font-semibold text-n-slate-11">
        {{ t(`CRM.COMMERCIAL_SUMMARY.${card.titleKey || card.key}`) }}
      </h3>
      <strong
        class="mt-1 block break-words text-lg font-bold text-n-slate-12"
        >{{ card.value }}</strong
      >
      <details class="mt-1 text-xs text-n-slate-11">
        <summary class="cursor-pointer py-1 font-medium text-n-blue-11">
          {{ t('CRM.DETAILS') }}
        </summary>
        <p class="mb-1 mt-1">
          {{
            t(`CRM.COMMERCIAL_SUMMARY.${card.helpKey || `${card.key}_HELP`}`)
          }}
        </p>
        <dl
          v-if="card.details.length"
          class="space-y-1 border-t border-n-weak pt-2"
        >
          <div
            v-for="[label, value] in card.details"
            :key="label"
            class="flex flex-wrap justify-between gap-1"
          >
            <dt>{{ label }}</dt>
            <dd class="font-semibold text-n-slate-12">{{ value }}</dd>
          </div>
        </dl>
      </details>
    </article>
  </section>
</template>
