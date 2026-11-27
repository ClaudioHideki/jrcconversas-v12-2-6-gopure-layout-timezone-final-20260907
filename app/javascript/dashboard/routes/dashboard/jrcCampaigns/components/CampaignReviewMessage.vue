<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { templateParts } from '../templateConfiguration';

const props = defineProps({
  step: { type: Object, required: true },
  definitions: { type: Array, default: () => [] },
});
const { t } = useI18n();
const definition = computed(() =>
  props.definitions.find(
    item =>
      item.name === props.step.template_name &&
      item.language?.toLowerCase() ===
        props.step.template_language?.toLowerCase()
  )
);
const parts = computed(() => templateParts(definition.value));
const params = computed(
  () => props.step.template_params?.processed_params || {}
);
const media = computed(() => ({
  url: params.value.header?.media_url || props.step.media_url,
  kind: params.value.header?.media_type || props.step.kind,
  name: params.value.header?.media_name,
}));
const kindLabel = computed(() => {
  const key = {
    template: 'TEMPLATE',
    text: 'TEXT',
    image: 'IMAGE',
    video: 'VIDEO',
    document: 'DOCUMENT',
    audio: 'AUDIO',
    email: 'EMAIL',
  }[props.step.kind];
  return key ? t(`JRC_CAMPAIGNS.WIZARD.${key}`) : props.step.kind;
});
const renderText = section =>
  String(parts.value[section]?.text || '').replace(
    /\{\{\s*([^{}]+?)\s*\}\}/g,
    (match, key) => params.value[section]?.[key] ?? match
  );
</script>

<template>
  <div class="min-w-0 space-y-3">
    <div class="flex flex-wrap items-center gap-2">
      <span
        class="rounded-full bg-n-teal-3 px-3 py-1 text-sm font-semibold text-n-teal-11"
      >
        {{ kindLabel }}
      </span>
      <span v-if="step.template_name" class="break-all text-sm font-medium">
        {{ step.template_name }}
      </span>
      <span v-if="step.template_language" class="text-sm text-n-slate-11">
        {{ step.template_language.replace('_', '-') }}
      </span>
    </div>
    <div
      class="overflow-hidden rounded-xl border border-n-weak bg-n-alpha-1 p-4"
    >
      <img
        v-if="media.url && media.kind === 'image'"
        :src="media.url"
        :alt="t('JRC_CAMPAIGNS.META.PREVIEW')"
        class="mb-3 max-h-56 w-full rounded-lg object-contain"
      />
      <video
        v-else-if="media.url && media.kind === 'video'"
        :src="media.url"
        controls
        preload="metadata"
        class="mb-3 max-h-56 w-full rounded-lg"
      />
      <audio
        v-else-if="media.url && media.kind === 'audio'"
        :src="media.url"
        controls
        preload="metadata"
        class="mb-3 w-full"
      />
      <a
        v-else-if="media.url"
        :href="media.url"
        target="_blank"
        rel="noopener noreferrer"
        class="mb-3 flex items-center gap-2 break-all text-n-blue-11 underline"
      >
        <span class="i-lucide-file-text size-5 shrink-0" />
        {{ media.name || t('JRC_CAMPAIGNS.WIZARD.DOCUMENT') }}
      </a>
      <p v-if="step.subject" class="mb-2 break-words font-semibold">
        {{ step.subject }}
      </p>
      <p v-if="renderText('header')" class="mb-2 break-words font-semibold">
        {{ renderText('header') }}
      </p>
      <p
        v-if="renderText('body') || step.body"
        class="whitespace-pre-wrap break-words leading-6"
      >
        {{ renderText('body') || step.body }}
      </p>
      <p v-else-if="step.kind === 'template'" class="text-sm text-n-slate-11">
        {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.TEMPLATE_CONTENT') }}
      </p>
      <p
        v-if="parts.footer?.text"
        class="mt-3 break-words text-sm text-n-slate-11"
      >
        {{ parts.footer.text }}
      </p>
      <div
        v-if="parts.buttons.length"
        class="mt-3 space-y-2 border-t border-n-weak pt-3 text-center text-sm font-medium text-n-blue-11"
      >
        <p
          v-for="(button, index) in parts.buttons"
          :key="index"
          class="break-words"
        >
          {{ button.text }}
        </p>
      </div>
    </div>
    <p v-if="step.follow_up_after_hours" class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.GOVERNANCE.FOLLOW_UP') }}:
      {{
        t('JRC_CAMPAIGNS.GOVERNANCE.HOURS', {
          count: step.follow_up_after_hours,
        })
      }}
    </p>
    <p v-if="step.delay_after_seconds" class="text-sm text-n-slate-11">
      {{ t('JRC_CAMPAIGNS.WIZARD.DELAY_AFTER') }}:
      {{ step.delay_after_seconds }}
    </p>
    <details
      v-if="Object.keys(step.template_params || {}).length"
      class="rounded-lg border border-n-weak text-sm"
    >
      <summary class="cursor-pointer px-3 py-2 font-medium text-n-slate-11">
        {{ t('JRC_CAMPAIGNS.REVIEW_LAYOUT.TECHNICAL') }}
      </summary>
      <div
        class="m-0 max-h-56 overflow-y-auto whitespace-pre-wrap break-all p-3 text-xs"
      >
        {{ JSON.stringify(step.template_params, null, 2) }}
      </div>
    </details>
  </div>
</template>
