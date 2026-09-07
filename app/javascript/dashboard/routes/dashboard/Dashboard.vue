<script>
import {
  defineAsyncComponent,
  ref,
  computed,
  onBeforeUnmount,
  watch,
} from 'vue';

import NextSidebar from 'next/sidebar/Sidebar.vue';
import WootKeyShortcutModal from 'dashboard/components/widgets/modal/WootKeyShortcutModal.vue';
import AddAccountModal from 'dashboard/components/app/AddAccountModal.vue';
import UpgradePage from 'dashboard/routes/dashboard/upgrade/UpgradePage.vue';

import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import { useWindowSize } from '@vueuse/core';

import wootConstants from 'dashboard/constants/globals';

const CommandBar = defineAsyncComponent(
  () => import('./commands/commandbar.vue')
);

const FloatingCallWidget = defineAsyncComponent(
  () => import('dashboard/components-next/call/FloatingCallWidget.vue')
);

import JrcCopilotLauncher from 'dashboard/components-next/jrcCopilot/JrcCopilotLauncher.vue';
import JrcCopilotPanel from 'dashboard/components-next/jrcCopilot/JrcCopilotPanel.vue';

import MobileSidebarLauncher from 'dashboard/components-next/sidebar/MobileSidebarLauncher.vue';
import JrcTopBar from 'dashboard/components-next/layout/JrcTopBar.vue';
import { useCallsStore } from 'dashboard/stores/calls';
import SipCallWidget from './webphone/SipCallWidget.vue';
import { useSipWebphone } from './webphone/useSipWebphone';

export default {
  components: {
    NextSidebar,
    CommandBar,
    WootKeyShortcutModal,
    AddAccountModal,
    UpgradePage,
    JrcCopilotLauncher,
    JrcCopilotPanel,
    FloatingCallWidget,
    MobileSidebarLauncher,
    JrcTopBar,
    SipCallWidget,
  },
  setup() {
    const upgradePageRef = ref(null);
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();
    const { width: windowWidth } = useWindowSize();
    const callsStore = useCallsStore();
    const sipWebphone = useSipWebphone();

    watch(accountId, value => sipWebphone.initialize(value), {
      immediate: true,
    });
    onBeforeUnmount(() => sipWebphone.shutdown());

    return {
      uiSettings,
      updateUISettings,
      accountId,
      upgradePageRef,
      windowWidth,
      hasActiveCall: computed(() => callsStore.hasActiveCall),
      hasIncomingCall: computed(() => callsStore.hasIncomingCall),
    };
  },
  data() {
    return {
      showAccountModal: false,
      showCreateAccountModal: false,
      showShortcutModal: false,
      isMobileSidebarOpen: false,
    };
  },
  computed: {
    isSmallScreen() {
      return this.windowWidth < wootConstants.SMALL_SCREEN_BREAKPOINT;
    },
    showUpgradePage() {
      return this.upgradePageRef?.shouldShowUpgradePage;
    },
    bypassUpgradePage() {
      return [
        'billing_settings_index',
        'settings_inbox_list',
        'general_settings_index',
        'agent_list',
      ].includes(this.$route.name);
    },
    previouslyUsedDisplayType() {
      const {
        previously_used_conversation_display_type: conversationDisplayType,
      } = this.uiSettings;
      return conversationDisplayType;
    },
  },
  watch: {
    isSmallScreen: {
      handler() {
        const { LAYOUT_TYPES } = wootConstants;
        if (window.innerWidth <= wootConstants.SMALL_SCREEN_BREAKPOINT) {
          this.updateUISettings({
            conversation_display_type: LAYOUT_TYPES.EXPANDED,
          });
        } else {
          this.updateUISettings({
            conversation_display_type: this.previouslyUsedDisplayType,
          });
        }
      },
      immediate: true,
    },
  },
  methods: {
    toggleMobileSidebar() {
      this.isMobileSidebarOpen = !this.isMobileSidebarOpen;
    },
    closeMobileSidebar() {
      this.isMobileSidebarOpen = false;
    },
    openCreateAccountModal() {
      this.showAccountModal = false;
      this.showCreateAccountModal = true;
    },
    closeCreateAccountModal() {
      this.showCreateAccountModal = false;
    },
    toggleAccountModal() {
      this.showAccountModal = !this.showAccountModal;
    },
    toggleKeyShortcutModal() {
      this.showShortcutModal = true;
    },
    closeKeyShortcutModal() {
      this.showShortcutModal = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-grow overflow-hidden text-n-slate-12">
    <NextSidebar
      :is-mobile-sidebar-open="isMobileSidebarOpen"
      @toggle-account-modal="toggleAccountModal"
      @open-key-shortcut-modal="toggleKeyShortcutModal"
      @close-key-shortcut-modal="closeKeyShortcutModal"
      @show-create-account-modal="openCreateAccountModal"
      @close-mobile-sidebar="closeMobileSidebar"
    />

    <main
      class="flex flex-1 flex-col h-full w-full min-h-0 overflow-hidden bg-n-surface-1"
    >
      <JrcTopBar />
      <div class="relative flex min-h-0 flex-1 overflow-hidden">
        <UpgradePage
          v-show="showUpgradePage"
          ref="upgradePageRef"
          :bypass-upgrade-page="bypassUpgradePage"
        >
          <MobileSidebarLauncher
            :is-mobile-sidebar-open="isMobileSidebarOpen"
            @toggle="toggleMobileSidebar"
          />
        </UpgradePage>
        <template v-if="!showUpgradePage">
          <div class="h-full w-full min-w-0 flex-1 overflow-hidden"><router-view /></div>
          <CommandBar />
          <JrcCopilotLauncher />
          <MobileSidebarLauncher
            :is-mobile-sidebar-open="isMobileSidebarOpen"
            @toggle="toggleMobileSidebar"
          />
          <JrcCopilotPanel />
          <FloatingCallWidget v-if="hasActiveCall || hasIncomingCall" />
          <SipCallWidget />
        </template>
      </div>
      <AddAccountModal
        :show="showCreateAccountModal"
        @close-account-create-modal="closeCreateAccountModal"
      />
      <WootKeyShortcutModal
        v-model:show="showShortcutModal"
        @close="closeKeyShortcutModal"
        @clickaway="closeKeyShortcutModal"
      />
    </main>
  </div>
</template>
