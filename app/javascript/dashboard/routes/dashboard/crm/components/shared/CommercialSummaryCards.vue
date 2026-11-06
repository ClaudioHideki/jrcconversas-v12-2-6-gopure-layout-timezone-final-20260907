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
    class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6"
    :aria-label="t('CRM.COMMERCIAL_SUMMARY.TITLE')"
  >
    <article
      v-for="card in cards"
      :key="card.key"
      class="min-w-0 rounded-2xl border border-n-weak bg-n-solid-2 p-4 shadow-sm"
    >
      <h3 class="text-sm font-semibold text-n-slate-11">
        {{ t(`CRM.COMMERCIAL_SUMMARY.${card.titleKey || card.key}`) }}
      </h3>
      <strong
        class="mt-3 block break-words text-xl font-bold text-n-slate-12"
        >{{ card.value }}</strong
      >
      <p class="mt-2 text-xs text-n-slate-11">
        {{ t(`CRM.COMMERCIAL_SUMMARY.${card.helpKey || `${card.key}_HELP`}`) }}
      </p>
      <dl
        v-if="card.details.length"
        class="mt-3 space-y-2 border-t border-n-weak pt-3 text-xs"
      >
        <div
          v-for="[label, value] in card.details"
          :key="label"
          class="flex flex-wrap justify-between gap-2"
        >
          <dt class="text-n-slate-11">{{ label }}</dt>
          <dd class="font-semibold text-n-slate-12">{{ value }}</dd>
        </div>
      </dl>
    </article>
  </section>
</template>
