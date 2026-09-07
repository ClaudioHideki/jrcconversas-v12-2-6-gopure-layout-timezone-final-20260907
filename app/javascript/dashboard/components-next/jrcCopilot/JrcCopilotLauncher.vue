<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import jrcCopilotAPI from 'dashboard/api/jrcCopilot';
import { useJrcCopilot } from './useJrcCopilot';

const route = useRoute();
const { isOpen, toggle } = useJrcCopilot();
const aiConfigured = ref(false);

const statusLabel = computed(() =>
  aiConfigured.value
    ? 'Abrir Copiloto JRC'
    : 'Copiloto JRC: IA não configurada pela conta'
);

const loadStatus = async () => {
  try {
    const { data } = await jrcCopilotAPI.context(route.name);
    aiConfigured.value = Boolean(data.ai_configured);
  } catch {
    aiConfigured.value = false;
  }
};

watch(
  () => route.name,
  () => loadStatus()
);
onMounted(loadStatus);
</script>

<template>
  <button
    v-if="!isOpen"
    type="button"
    class="group fixed bottom-5 ltr:right-5 rtl:left-5 z-50 grid size-16 place-content-center rounded-full border-2 border-cyan-300/80 bg-white shadow-[0_18px_45px_rgba(5,57,96,0.34)] transition hover:-translate-y-1 hover:scale-105 hover:shadow-[0_22px_55px_rgba(5,57,96,0.44)]"
    :aria-label="statusLabel"
    :title="statusLabel"
    @click="toggle"
  >
    <img
      :src="'/brand-assets/jrc-copilot-avatar.png'"
      alt="Mascote do Copiloto JRC"
      class="size-[58px] rounded-full object-cover"
    />
    <span
      class="absolute right-0 top-0 size-4 rounded-full border-2 border-white"
      :class="aiConfigured ? 'bg-emerald-500' : 'bg-slate-400'"
    />
  </button>
</template>
