<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import API from 'dashboard/api/cannedResponse';
const props = defineProps({
  accountId: { type: Number, required: true },
  conversationId: { type: Number, required: true },
  disabled: Boolean,
  authorityKey: { type: String, default: '' },
  canAttach: { type: Function, required: true },
  canInsert: { type: Boolean, default: true },
  canSendCombined: { type: Boolean, default: true },
  maxLength: { type: Number, default: 10000 },
  prepareContent: { type: Function, default: value => value },
  onInsert: { type: Function, required: true },
  isContextCurrent: { type: Function, required: true },
});
const emit = defineEmits(['delivered', 'toggle']);
const { t } = useI18n();
const dialog = ref(null);
const confirmation = ref(null);
const records = ref([]);
const selected = ref(null);
const content = ref('');
const search = ref('');
const busy = ref(false);
const error = ref('');
const uncertain = ref(false);
const previewUrl = ref('');
let cachedFile = null;
let generation = 0;
let intent = '';
const filtered = computed(() =>
  records.value.filter(row =>
    `${row.short_code} ${row.content}`
      .toLocaleLowerCase()
      .includes(search.value.toLocaleLowerCase())
  )
);
const attachmentAllowed = computed(
  () => !selected.value?.file || props.canAttach(selected.value.file)
);
const hasUnresolved = computed(() =>
  /\[(nome|vendedor|empresa|cidade|região|data|produto\/serviço)\]|\{\{|\{%/.test(
    content.value
  )
);
// A second native Liquid pass must not execute expressions introduced by contact data.
const hasLiquidExpression = computed(() => /\{\{|\{%/.test(content.value));
const currentContext = () =>
  !props.disabled &&
  props.isContextCurrent({
    accountId: props.accountId,
    conversationId: props.conversationId,
    authorityKey: props.authorityKey,
  });
const sendAllowed = computed(
  () =>
    !props.disabled &&
    !hasUnresolved.value &&
    content.value.length <= props.maxLength &&
    attachmentAllowed.value &&
    (!selected.value?.file || props.canSendCombined)
);
const reset = () => {
  emit('toggle', false);
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
  previewUrl.value = '';
  cachedFile = null;
  generation += 1;
  records.value = [];
  selected.value = null;
  content.value = '';
  search.value = '';
  error.value = '';
  busy.value = false;
  uncertain.value = false;
  intent = '';
  confirmation.value?.close();
};
const close = () => {
  reset();
  dialog.value?.close();
};
const choose = async row => {
  if (busy.value || !currentContext()) return;
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
  previewUrl.value = '';
  cachedFile = null;
  selected.value = null;
  content.value = '';
  const current = generation;
  busy.value = true;
  error.value = '';
  try {
    const result = await API.preview(
      row.id,
      props.conversationId,
      props.accountId
    );
    if (current !== generation) return;
    selected.value = result.data;
    content.value = props.prepareContent(result.data.content);
    intent = crypto.randomUUID();
    uncertain.value = false;
    if (result.data.file?.content_type?.startsWith('image/')) {
      const image = await API.file(row.id, props.accountId, {
        revision: result.data.revision,
        attachment_id: result.data.file.id,
      });
      if (current !== generation) return;
      cachedFile = new File([image.data], result.data.file.filename, {
        type: result.data.file.content_type,
      });
      if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
      previewUrl.value = URL.createObjectURL(image.data);
    }
  } catch {
    if (current === generation) error.value = t('CANNED_MGMT.QUICK.ERROR');
  } finally {
    if (current === generation) busy.value = false;
  }
};
const open = async responseId => {
  if (!currentContext()) return;
  reset();
  const current = generation;
  dialog.value.open();
  emit('toggle', true);
  busy.value = true;
  let initial;
  try {
    const result = await API.get({ searchKey: '', accountId: props.accountId });
    if (current === generation) {
      records.value = result.data;
      initial = records.value.find(row => row.id === responseId);
    }
  } catch {
    if (current === generation) error.value = t('CANNED_MGMT.QUICK.ERROR');
  } finally {
    if (current === generation) busy.value = false;
  }
  if (initial && current === generation) await choose(initial);
};
const insert = async () => {
  if (
    busy.value ||
    !props.canInsert ||
    hasLiquidExpression.value ||
    !currentContext() ||
    !attachmentAllowed.value
  )
    return;
  const current = generation;
  const context = {
    accountId: props.accountId,
    conversationId: props.conversationId,
    authorityKey: props.authorityKey,
  };
  busy.value = true;
  error.value = '';
  try {
    let file;
    if (selected.value.file) {
      if (cachedFile) file = cachedFile;
      else {
        const result = await API.file(selected.value.id, props.accountId, {
          revision: selected.value.revision,
          attachment_id: selected.value.file.id,
        });
        if (current !== generation) return;
        file = new File([result.data], selected.value.file.filename, {
          type: selected.value.file.content_type,
        });
      }
    }
    if (!currentContext()) return;
    await props.onInsert({ content: content.value, file, ...context });
    if (current === generation) close();
  } catch {
    if (current === generation) error.value = t('CANNED_MGMT.QUICK.ERROR');
  } finally {
    if (current === generation) busy.value = false;
  }
};
const send = async () => {
  confirmation.value.close();
  if (busy.value || !currentContext() || !sendAllowed.value) return;
  const current = generation;
  busy.value = true;
  error.value = '';
  try {
    const result = await API.deliver(
      selected.value.id,
      {
        conversation_id: props.conversationId,
        content: content.value,
        delivery_key: intent,
        confirmed: true,
        revision: selected.value.revision,
        actor_id: selected.value.actor_id,
        context: selected.value.context,
      },
      props.accountId
    );
    if (current === generation && currentContext()) {
      emit('delivered', result.data);
      close();
    }
  } catch (cause) {
    if (current === generation) {
      const rejected = [
        'ACTOR_CHANGED',
        'CONTEXT_CHANGED',
        'ATTACHMENT_NOT_ALLOWED',
        'ATTACHMENT_UNAVAILABLE',
        'UNRESOLVED_VARIABLES',
        'RESPONSE_CHANGED',
        'MESSAGE_WINDOW_CLOSED',
        'CHANNEL_REQUIRES_SEPARATE_MESSAGES',
        'CONTENT_TOO_LONG',
      ].includes(cause.response?.data?.error);
      uncertain.value = !rejected;
      error.value = rejected
        ? t('CANNED_MGMT.QUICK.REVIEW_ERROR')
        : t('CANNED_MGMT.QUICK.SEND_ERROR');
    }
  } finally {
    if (current === generation) busy.value = false;
  }
};
watch(
  () => [
    props.accountId,
    props.conversationId,
    props.disabled,
    props.authorityKey,
  ],
  close
);
onBeforeUnmount(reset);
defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="t('CANNED_MGMT.QUICK.TITLE')"
    :show-confirm-button="false"
    show-close-button
    contained
    width="xl"
    @close="reset"
  >
    <div class="min-w-0 space-y-4 text-n-slate-12">
      <p v-if="error" role="alert" class="text-n-ruby-11">{{ error }}</p>
      <p v-if="busy" role="status">{{ t('CANNED_MGMT.QUICK.LOADING') }}</p>
      <template v-if="!selected">
        <input
          v-model="search"
          type="search"
          :aria-label="t('CANNED_MGMT.QUICK.SEARCH')"
          :placeholder="t('CANNED_MGMT.QUICK.SEARCH')"
          class="w-full bg-n-solid-2"
        />
        <div class="max-h-80 space-y-2 overflow-auto">
          <button
            v-for="row in filtered"
            :key="row.id"
            type="button"
            :disabled="busy"
            class="block w-full rounded-lg border border-n-weak bg-n-solid-2 p-3 text-left text-n-slate-12"
            @click="choose(row)"
          >
            <strong>{{ row.short_code }}</strong>
            <p class="m-0 whitespace-pre-wrap break-words text-sm">
              {{ row.content }}
            </p>
            <span v-if="row.file" class="text-xs">{{ row.file.filename }}</span>
          </button>
        </div>
      </template>
      <template v-else>
        <label class="block">
          <span>{{ t('CANNED_MGMT.QUICK.REVIEW') }}</span>
          <textarea
            v-model="content"
            :disabled="busy || uncertain"
            rows="8"
            class="mt-2 min-h-40 w-full resize-y bg-n-solid-2 text-n-slate-12"
          />
        </label>
        <p v-if="hasUnresolved" class="text-sm text-n-amber-11">
          {{ t('CANNED_MGMT.QUICK.MISSING') }}
        </p>
        <p v-if="hasLiquidExpression" class="text-sm text-n-amber-11">
          {{ t('CANNED_MGMT.QUICK.TEMPLATE_REVIEW') }}
        </p>
        <p
          v-if="content.length > maxLength"
          role="status"
          class="text-sm text-n-amber-11"
        >
          {{ t('CANNED_MGMT.QUICK.TOO_LONG', { limit: maxLength }) }}
        </p>
        <p
          v-if="selected.file"
          class="break-words rounded-lg border border-n-weak p-3"
        >
          {{ selected.file.filename }}
        </p>
        <img
          v-if="previewUrl"
          :src="previewUrl"
          :alt="selected.file.filename"
          class="max-h-48 max-w-full rounded-lg object-contain"
        />
        <p
          v-if="!attachmentAllowed || (selected.file && !canSendCombined)"
          role="status"
          class="text-sm text-n-amber-11"
        >
          {{ t('CANNED_MGMT.QUICK.CHANNEL') }}
        </p>
        <div class="flex flex-wrap gap-2">
          <Button
            type="button"
            :label="t('CANNED_MGMT.QUICK.BACK')"
            variant="faded"
            :disabled="busy || uncertain"
            @click="selected = null"
          />
          <Button
            type="button"
            :label="t('CANNED_MGMT.QUICK.INSERT')"
            :disabled="
              busy ||
              disabled ||
              !canInsert ||
              !attachmentAllowed ||
              hasLiquidExpression
            "
            @click="insert"
          />
          <Button
            type="button"
            :label="t('CANNED_MGMT.QUICK.SEND')"
            :disabled="busy || !sendAllowed || !content.trim()"
            @click="confirmation.open()"
          />
        </div>
      </template>
    </div>
  </Dialog>
  <Dialog
    ref="confirmation"
    :title="t('CANNED_MGMT.QUICK.CONFIRM')"
    :description="t('CANNED_MGMT.QUICK.CONFIRM_HELP')"
    :confirm-button-label="t('CANNED_MGMT.QUICK.SEND')"
    :disable-confirm-button="busy || !sendAllowed"
    contained
    show-close-button
    @confirm="send"
  >
    <div
      v-if="selected"
      class="min-w-0 space-y-3 text-n-slate-12"
      data-testid="quick-reply-confirmation"
    >
      <dl class="m-0 space-y-2 text-sm">
        <div>
          <dt class="font-semibold">{{ t('CANNED_MGMT.QUICK.RECIPIENT') }}</dt>
          <dd class="m-0 break-words">
            {{
              t('CANNED_MGMT.QUICK.RECIPIENT_VALUE', {
                name: selected.recipient?.name || '',
                address: selected.recipient?.address || '',
                id: conversationId,
              })
            }}
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            {{ t('CANNED_MGMT.QUICK.CHANNEL_LABEL') }}
          </dt>
          <dd class="m-0 break-words">
            {{
              t('CANNED_MGMT.QUICK.CHANNEL_VALUE', {
                name: selected.channel?.name || '',
                type: selected.channel?.type || '',
              })
            }}
          </dd>
        </div>
      </dl>
      <p
        class="max-h-48 overflow-auto whitespace-pre-wrap break-words rounded-lg border border-n-weak p-3"
      >
        {{ content }}
      </p>
      <p class="break-words text-sm">
        {{ selected.file?.filename || t('CANNED_MGMT.QUICK.NO_FILE') }}
      </p>
      <img
        v-if="previewUrl"
        :src="previewUrl"
        :alt="selected.file.filename"
        class="max-h-32 max-w-full rounded-lg object-contain"
      />
      <p v-if="hasUnresolved" role="status" class="text-sm text-n-amber-11">
        {{ t('CANNED_MGMT.QUICK.MISSING') }}
      </p>
    </div>
  </Dialog>
</template>
