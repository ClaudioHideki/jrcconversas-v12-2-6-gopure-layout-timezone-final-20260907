import { computed, ref, watch, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import ConversationAPI from 'dashboard/api/conversations';
import { windowState } from 'dashboard/helper/whatsappTemplateFlow.mjs';

export function useWhatsappWindow() {
  const store = useStore();
  const chat = computed(() => store.getters.getSelectedChat || {});
  const inbox = computed(() => store.getters['inboxes/getInbox'](chat.value.inbox_id) || {});
  const isOfficial = computed(() => inbox.value.channel_type === 'Channel::Whatsapp');
  const snapshot = ref(null);
  const elapsed = ref(0);
  const refreshing = ref(false);
  const refreshError = ref(false);
  let receivedAt = performance.now();
  let generation = 0;
  let tick;
  let poll;
  let mounted = false;

  const applySnapshot = data => {
    if (!data?.has_service_window) return;
    if (snapshot.value && Date.parse(data.server_time) < Date.parse(snapshot.value.server_time)) return;
    snapshot.value = data;
    receivedAt = performance.now();
    elapsed.value = 0;
  };
  const state = computed(() => windowState(snapshot.value, elapsed.value));
  const refresh = async () => {
    if (!isOfficial.value || !chat.value.id) return;
    const id = chat.value.id;
    const request = ++generation;
    refreshing.value = true;
    try {
      const { data } = await ConversationAPI.whatsappWindow(id);
      if (request !== generation || chat.value.id !== id || !mounted) return;
      applySnapshot(data);
      refreshError.value = false;
    } catch {
      if (request === generation) refreshError.value = true;
    } finally {
      if (request === generation) refreshing.value = false;
    }
  };
  const onVisible = () => {
    if (document.visibilityState === 'visible') refresh();
  };
  watch(() => [chat.value.id, isOfficial.value], () => {
    generation += 1;
    snapshot.value = null;
    refreshError.value = false;
    applySnapshot(chat.value.whatsapp_window);
    if (mounted) refresh();
  }, { immediate: true });
  watch(() => chat.value.whatsapp_window, applySnapshot);
  onMounted(() => {
    mounted = true;
    refresh();
    tick = setInterval(() => { elapsed.value = performance.now() - receivedAt; }, 1000);
    poll = setInterval(onVisible, 30000);
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('online', refresh);
  });
  onUnmounted(() => {
    mounted = false;
    generation += 1;
    clearInterval(tick);
    clearInterval(poll);
    document.removeEventListener('visibilitychange', onVisible);
    window.removeEventListener('online', refresh);
  });
  return { isOfficial, state, refresh, refreshing, refreshError };
}
