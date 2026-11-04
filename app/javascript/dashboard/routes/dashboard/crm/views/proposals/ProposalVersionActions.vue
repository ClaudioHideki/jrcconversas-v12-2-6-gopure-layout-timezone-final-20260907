<script setup>
import { useI18n } from 'vue-i18n';
defineProps({
  historical: Boolean,
  busy: Boolean,
  actions: {
    type: Object,
    default: () => ({ revise: true, resend: true, history: true }),
  },
});
defineEmits(['revise', 'resend', 'history']);
const { t } = useI18n();
</script>

<template>
  <div
    class="mt-4 min-w-0"
    :class="
      historical ? 'rounded-xl border border-n-amber-6 bg-n-amber-2 p-4' : ''
    "
  >
    <p
      v-if="historical"
      role="status"
      class="mb-3 text-sm font-medium text-n-amber-11"
    >
      {{ t('CRM.VERSIONS.WARNING') }}
    </p>
    <div class="flex flex-wrap gap-2">
      <button
        v-if="actions.revise"
        type="button"
        data-version-action="revise"
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-n-brand px-4 py-3 text-sm font-semibold text-white shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand disabled:opacity-50"
        :disabled="busy"
        @click="$emit('revise')"
      >
        <i
          class="i-lucide-file-pen-line size-4 shrink-0"
          aria-hidden="true"
        />{{ t('CRM.VERSIONS.EDIT') }}
      </button>
      <button
        v-if="actions.resend"
        type="button"
        data-version-action="resend"
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-n-brand bg-n-blue-2 px-4 py-3 text-sm font-semibold text-n-blue-11 shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand disabled:opacity-50"
        :disabled="busy"
        @click="$emit('resend')"
      >
        <i class="i-lucide-send size-4 shrink-0" aria-hidden="true" />{{
          t('CRM.VERSIONS.RESEND')
        }}
      </button>
      <button
        v-if="actions.history"
        type="button"
        data-version-action="history"
        class="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-n-weak bg-n-solid-2 px-4 py-3 text-sm font-semibold text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand disabled:opacity-50"
        :disabled="busy"
        @click="$emit('history')"
      >
        <i class="i-lucide-history size-4 shrink-0" aria-hidden="true" />{{
          t('CRM.VERSIONS.HISTORY')
        }}
      </button>
    </div>
  </div>
</template>
