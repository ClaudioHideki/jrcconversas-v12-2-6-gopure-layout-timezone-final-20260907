<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import API from 'dashboard/api/cannedResponse';
const props = defineProps({
  initialFile: { type: Object, default: null },
  responseId: { type: Number, default: null },
  accountId: { type: Number, default: null },
  disabled: Boolean,
});
const emit = defineEmits(['change']);
const { t } = useI18n();
const input = ref(null);
const selected = ref(null);
const removed = ref(false);
const preview = ref('');
const error = ref('');
let generation = 0;
const filename = computed(
  () => selected.value?.name || (!removed.value && props.initialFile?.filename)
);
const release = () => {
  if (preview.value) URL.revokeObjectURL(preview.value);
  preview.value = '';
};
const select = event => {
  const file = event.target.files?.[0];
  if (!file) return;
  release();
  generation += 1;
  error.value = '';
  selected.value = file;
  removed.value = false;
  if (
    ['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)
  )
    preview.value = URL.createObjectURL(file);
  emit('change', { file, remove_file: false });
};
const remove = () => {
  release();
  generation += 1;
  error.value = '';
  selected.value = null;
  removed.value = true;
  if (input.value) input.value.value = '';
  emit('change', { file: null, remove_file: true });
};
const fetchInitialFile = () =>
  API.file(props.responseId, props.accountId, {
    revision: props.initialFile.revision,
    attachment_id: props.initialFile.id,
  });
const download = async () => {
  const current = generation;
  error.value = '';
  try {
    const blob = selected.value || (await fetchInitialFile()).data;
    if (current !== generation) return;
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename.value;
    link.click();
    URL.revokeObjectURL(url);
  } catch {
    if (current === generation) error.value = t('CANNED_MGMT.QUICK.ERROR');
  }
};
watch(
  () => [props.initialFile, props.responseId, props.accountId],
  async () => {
    generation += 1;
    const current = generation;
    release();
    selected.value = null;
    removed.value = false;
    error.value = '';
    if (!props.initialFile?.content_type?.startsWith('image/')) return;
    try {
      const result = await fetchInitialFile();
      if (current === generation)
        preview.value = URL.createObjectURL(result.data);
    } catch {
      if (current === generation) error.value = t('CANNED_MGMT.QUICK.ERROR');
    }
  },
  { immediate: true }
);
onBeforeUnmount(() => {
  generation += 1;
  release();
});
</script>

<template>
  <div class="space-y-2 rounded-lg border border-n-weak p-3 text-n-slate-12">
    <p class="m-0 text-sm">{{ t('CANNED_MGMT.QUICK.FILE_HELP') }}</p>
    <p v-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <input
      ref="input"
      type="file"
      class="hidden"
      :disabled="disabled"
      @change="select"
    />
    <div class="flex flex-wrap gap-2">
      <Button
        type="button"
        :label="t('CANNED_MGMT.QUICK.ATTACH')"
        icon="i-ph-paperclip"
        :disabled="disabled"
        @click="input.click()"
      />
      <Button
        v-if="filename"
        type="button"
        :label="t('CANNED_MGMT.QUICK.DOWNLOAD')"
        variant="faded"
        :disabled="disabled"
        @click="download"
      />
      <Button
        v-if="filename"
        type="button"
        :label="t('CANNED_MGMT.QUICK.REMOVE')"
        variant="faded"
        :disabled="disabled"
        @click="remove"
      />
    </div>
    <p v-if="filename" class="m-0 break-words text-sm">{{ filename }}</p>
    <img
      v-if="preview"
      :src="preview"
      :alt="filename"
      class="max-h-40 max-w-full rounded-lg object-contain"
    />
  </div>
</template>
