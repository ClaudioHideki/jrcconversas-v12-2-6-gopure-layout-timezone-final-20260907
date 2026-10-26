<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { useMapGetter } from 'dashboard/composables/store';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

defineProps({ requestClosing: { type: Function, default: null } });
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const actionsPopover = ref(null);
const assignPopover = ref(null);

const TEXT = Object.freeze({
  snooze: 'Adiar',
  assign: 'Atribuir',
});

const currentChat = computed(() => store.getters.getSelectedChat);
watch(
  () => currentChat.value.id,
  () => {
    assignPopover.value?.hide();
    actionsPopover.value?.hide();
  }
);
const assignableAgentsByInbox = useMapGetter(
  'inboxAssignableAgents/getAssignableAgents'
);
const assignableAgents = computed(() =>
  assignableAgentsByInbox.value(String(currentChat.value.inbox_id || ''))
);
const agentMenuItems = computed(() =>
  assignableAgents.value.map(agent => ({
    action: 'assign',
    value: agent.id,
    label: agent.name,
    thumbnail: { name: agent.name, src: agent.thumbnail },
  }))
);

const openSnoozeModal = () => {
  document.querySelector('ninja-keys')?.open({ parent: 'snooze_conversation' });
};

const openAssignDropdown = () => {
  actionsPopover.value?.hide();
  if (currentChat.value.inbox_id) {
    store.dispatch('inboxAssignableAgents/fetch', [currentChat.value.inbox_id]);
  }
};

const assignAgent = async ({ value }) => {
  await store.dispatch('assignAgent', {
    conversationId: currentChat.value.id,
    agentId: value,
  });
  assignPopover.value?.hide();
};

const actionMenuItems = computed(() => {
  const items = [];

  if (!currentChat.value.muted) {
    items.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    items.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  items.push({
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  });

  return items;
});

const handleActionClick = ({ action }) => {
  actionsPopover.value?.hide();

  if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="actions--container relative flex items-center gap-2">
    <ResolveAction
      :request-closing="requestClosing"
      :conversation-id="currentChat.id"
      :status="currentChat.status"
      prominent
      hide-additional-actions
    />
    <ButtonV4
      :label="TEXT.snooze"
      icon="i-lucide-clock-3"
      size="sm"
      color="amber"
      @click="openSnoozeModal"
    />
    <Popover ref="assignPopover" @show="openAssignDropdown">
      <template #default="{ isOpen }">
        <ButtonV4
          :label="TEXT.assign"
          icon="i-lucide-user-round-check"
          size="sm"
          color="blue"
          :aria-expanded="isOpen"
        />
      </template>
      <template #content>
        <DropdownMenu
          :menu-items="agentMenuItems"
          class="!relative max-h-80 w-64 max-w-full"
          show-search
          @action="assignAgent"
        />
      </template>
    </Popover>
    <Popover ref="actionsPopover" @show="assignPopover?.hide()">
      <template #default="{ isOpen }">
        <ButtonV4
          v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
          :aria-label="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
          :aria-expanded="isOpen"
          size="sm"
          variant="ghost"
          color="slate"
          icon="i-lucide-more-vertical"
          class="rounded-lg"
        />
      </template>
      <template #content>
        <DropdownMenu
          :menu-items="actionMenuItems"
          class="!relative max-h-80"
          @action="handleActionClick"
        />
      </template>
    </Popover>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
  </div>
</template>
