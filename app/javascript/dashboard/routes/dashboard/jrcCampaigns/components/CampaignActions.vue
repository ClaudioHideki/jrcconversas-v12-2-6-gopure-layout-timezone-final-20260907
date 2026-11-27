<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { Dropdown } from 'floating-vue';

defineProps({
  campaign: { type: Object, required: true },
  deleting: { type: Boolean, default: false },
});
const emit = defineEmits([
  'review',
  'launch',
  'pause',
  'resume',
  'cancel',
  'edit',
  'report',
  'duplicate',
  'delete',
]);
const { t } = useI18n();
const open = ref(false);
const trigger = ref(null);
const menu = ref(null);
const close = () => {
  open.value = false;
  trigger.value?.focus();
};
const focusFirst = () =>
  menu.value?.querySelector('button:not(:disabled)')?.focus();
const moveFocus = event => {
  const buttons = [...menu.value.querySelectorAll('button:not(:disabled)')];
  const current = buttons.indexOf(document.activeElement);
  const offset = event.key === 'ArrowUp' ? -1 : 1;
  buttons[(current + offset + buttons.length) % buttons.length]?.focus();
};
</script>

<template>
  <Dropdown
    :shown="open"
    :triggers="[]"
    placement="bottom-end"
    strategy="fixed"
    :overflow-padding="12"
    no-auto-focus
    popper-class="[&_.v-popper__inner]:!rounded-xl [&_.v-popper__inner]:!border-n-weak [&_.v-popper__inner]:!bg-n-background [&_.v-popper__arrow-container]:hidden"
    @update:shown="open = $event"
    @apply-show="focusFirst"
  >
    <button
      ref="trigger"
      type="button"
      class="flex size-9 items-center justify-center rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
      :aria-label="t('JRC_CAMPAIGNS.ACTIONS_NAMED', { name: campaign.name })"
      :aria-expanded="open"
      aria-haspopup="true"
      @click="open = !open"
      @keydown.down.prevent="open = true"
      @keydown.esc.stop.prevent="close"
    >
      <span class="i-lucide-ellipsis size-5" />
    </button>
    <template #popper>
      <div
        ref="menu"
        class="flex w-64 max-w-[calc(100vw-24px)] flex-col gap-1 p-2 text-sm [&>button]:flex [&>button]:min-h-10 [&>button]:items-center [&>button]:gap-3 [&>button]:rounded-lg [&>button]:px-3 [&>button]:py-2 [&>button]:text-left [&>button:hover]:bg-n-alpha-2 [&>button:disabled]:cursor-not-allowed [&>button:disabled]:opacity-50 [&>button:focus-visible]:ring-2 [&>button:focus-visible]:ring-n-brand"
        :aria-label="t('JRC_CAMPAIGNS.TABLE.ACTIONS')"
        @keydown.esc.stop.prevent="close"
        @keydown.down.prevent="moveFocus"
        @keydown.up.prevent="moveFocus"
      >
        <button
          v-if="['draft', 'scheduled'].includes(campaign.status)"
          type="button"
          :title="t('JRC_CAMPAIGNS.GOVERNANCE.REVIEW')"
          @click="
            close();
            emit('review', campaign);
          "
        >
          <span class="i-lucide-shield-check size-4 text-n-violet-11" />
          {{ t('JRC_CAMPAIGNS.GOVERNANCE.REVIEW') }}
        </button>
        <button
          v-if="campaign.status === 'draft'"
          type="button"
          :title="t('JRC_CAMPAIGNS.START')"
          @click="
            close();
            emit('launch', campaign);
          "
        >
          <span class="i-lucide-play size-4 text-n-teal-11" />
          {{ t('JRC_CAMPAIGNS.START') }}
        </button>
        <button
          v-if="campaign.status === 'running'"
          type="button"
          :title="t('JRC_CAMPAIGNS.PAUSE')"
          @click="
            close();
            emit('pause', campaign);
          "
        >
          <span class="i-lucide-pause size-4 text-n-amber-11" />
          {{ t('JRC_CAMPAIGNS.PAUSE') }}
        </button>
        <button
          v-if="campaign.status === 'paused'"
          type="button"
          :title="t('JRC_CAMPAIGNS.RESUME')"
          @click="
            close();
            emit('resume', campaign);
          "
        >
          <span class="i-lucide-play size-4 text-n-teal-11" />
          {{ t('JRC_CAMPAIGNS.RESUME') }}
        </button>
        <button
          v-if="['running', 'paused', 'scheduled'].includes(campaign.status)"
          type="button"
          :title="t('JRC_CAMPAIGNS.CANCEL')"
          @click="
            close();
            emit('cancel', campaign);
          "
        >
          <span class="i-lucide-square size-4 text-n-ruby-11" />
          {{ t('JRC_CAMPAIGNS.CANCEL') }}
        </button>
        <button
          type="button"
          :disabled="!['draft', 'scheduled'].includes(campaign.status)"
          :title="t('JRC_CAMPAIGNS.EDIT')"
          @click="
            close();
            emit('edit', campaign);
          "
        >
          <span class="i-lucide-pencil size-4 text-n-blue-11" />
          {{ t('JRC_CAMPAIGNS.EDIT') }}
        </button>
        <button
          type="button"
          :title="t('JRC_CAMPAIGNS.REPORT')"
          @click="
            close();
            emit('report', campaign);
          "
        >
          <span
            class="i-lucide-chart-no-axes-column-increasing size-4 text-n-violet-11"
          />
          {{ t('JRC_CAMPAIGNS.REPORT') }}
        </button>
        <button
          type="button"
          :title="t('JRC_CAMPAIGNS.DUPLICATE')"
          @click="
            close();
            emit('duplicate', campaign);
          "
        >
          <span class="i-lucide-copy size-4" />
          {{ t('JRC_CAMPAIGNS.DUPLICATE') }}
        </button>
        <div class="my-1 border-t border-n-weak" />
        <button
          type="button"
          class="text-n-ruby-11"
          :disabled="
            ['running', 'paused'].includes(campaign.status) || deleting
          "
          :title="
            t(
              ['running', 'paused'].includes(campaign.status)
                ? 'JRC_CAMPAIGNS.DELETE_ACTIVE_HELP'
                : 'JRC_CAMPAIGNS.DELETE'
            )
          "
          :aria-label="t('JRC_CAMPAIGNS.DELETE_NAMED', { name: campaign.name })"
          @click="
            close();
            emit('delete', campaign);
          "
        >
          <span class="i-lucide-trash-2 size-4" />
          {{ t('JRC_CAMPAIGNS.DELETE') }}
        </button>
      </div>
    </template>
  </Dropdown>
</template>
