<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const store = useStore();
const route = useRoute();
const router = useRouter();
const inboxes = useMapGetter('inboxes/getInboxes');
const getInboxUnreadCount = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);

const emailInboxes = computed(() =>
  inboxes.value.filter(inbox =>
    String(inbox.channel_type || inbox.channelType || '')
      .toLowerCase()
      .includes('email')
  )
);
const totalUnread = computed(() =>
  emailInboxes.value.reduce(
    (total, inbox) => total + Number(getInboxUnreadCount.value(inbox.id) || 0),
    0
  )
);

const openInbox = inbox =>
  router.push({
    name: 'inbox_dashboard',
    params: { accountId: route.params.accountId, inbox_id: inbox.id },
  });
const openRoute = name =>
  router.push({ name, params: { accountId: route.params.accountId } });
const openEmailInbox = () =>
  router.push({
    name: 'inbox_view',
    params: { accountId: route.params.accountId },
    query: { channel: 'email' },
  });

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('conversationUnreadCounts/get');
});
</script>

<template>
  <main class="jrc-visible-scrollbar h-full overflow-y-auto p-4 sm:p-6" style="background:linear-gradient(135deg,#eff6ff 0%%,#ffffff 48%%,#f5f3ff 100%%)">
    <div class="mx-auto flex max-w-[1400px] flex-col gap-5">
      <header class="rounded-3xl border p-6 shadow-sm" style="background:linear-gradient(135deg,#dbeafe,#eff6ff);border-color:#60a5fa">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="flex items-start gap-4">
            <span class="flex size-12 items-center justify-center rounded-2xl text-white shadow-md" style="background:#2563eb;color:#ffffff"><span class="i-lucide-mail-open size-6" /></span>
            <div>
              <h1 class="text-3xl font-bold text-n-slate-12">E-mails</h1>
              <p class="mt-1 text-sm text-n-slate-10">Módulo separado para as caixas de e-mail conectadas ao JRC Conversas.</p>
            </div>
          </div>
          <div class="flex gap-2">
            <button class="rounded-xl border border-n-weak bg-n-solid-2 px-4 py-2.5 text-sm font-semibold text-n-slate-11" @click="openRoute('jrc_cockpit')">Cockpit</button>
            <button class="rounded-xl px-4 py-2.5 text-sm font-semibold text-white shadow-md" style="background:#2563eb;color:#ffffff" @click="openRoute('settings_inbox_list')"><span class="i-lucide-settings-2 mr-1 size-4" />Contas de e-mail</button>
          </div>
        </div>
      </header>

      <nav class="flex flex-wrap gap-2 rounded-2xl border border-n-weak bg-white p-2 shadow-sm dark:bg-n-solid-2" aria-label="Navegação do módulo de e-mail">
        <button type="button" class="inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold text-white shadow-sm" style="background:#2563eb;color:#ffffff">
          <span class="i-lucide-layout-dashboard size-4" /> Visão geral
        </button>
      </nav>

      <section class="grid gap-4 sm:grid-cols-3">
        <article class="rounded-2xl border p-5 shadow-sm" style="background:#dbeafe;border-color:#3b82f6;border-top:4px solid #2563eb"><span class="text-sm font-semibold text-blue-700">Caixas configuradas</span><strong class="mt-2 block text-3xl text-blue-700">{{ emailInboxes.length }}</strong></article>
        <article class="rounded-2xl border p-5 shadow-sm" style="background:#ede9fe;border-color:#8b5cf6;border-top:4px solid #7c3aed"><span class="text-sm font-semibold text-violet-700">Não lidos</span><strong class="mt-2 block text-3xl text-violet-700">{{ totalUnread }}</strong></article>
        <article class="rounded-2xl border p-5 shadow-sm" style="background:#dcfce7;border-color:#22c55e;border-top:4px solid #16a34a"><span class="text-sm font-semibold text-emerald-700">Organização</span><strong class="mt-2 block text-lg text-emerald-700">Separada de Conversas</strong></article>
      </section>

      <section class="rounded-3xl border border-n-weak bg-white p-5 shadow-sm dark:bg-n-solid-2">
        <div class="flex items-center justify-between gap-3 border-b border-n-weak pb-4">
          <div><h2 class="text-lg font-bold text-n-slate-12">Caixas de e-mail</h2><p class="text-sm text-n-slate-9">Selecione uma conta para abrir a fila correspondente.</p></div>
        </div>
        <div v-if="emailInboxes.length" class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <button v-for="inbox in emailInboxes" :key="inbox.id" type="button" class="group rounded-2xl border p-4 text-left transition hover:-translate-y-0.5 hover:shadow-md" style="background:linear-gradient(135deg,#ecfeff,#f0f9ff);border-color:#22d3ee;border-top:4px solid #06b6d4" @click="openInbox(inbox)">
            <div class="flex items-center justify-between"><span class="flex size-10 items-center justify-center rounded-xl text-white" style="background:#f59e0b;color:#ffffff"><span class="i-lucide-mail size-5" /></span><span class="rounded-full bg-violet-100 px-2.5 py-1 text-xs font-bold text-violet-700 shadow-sm dark:bg-n-solid-2">{{ getInboxUnreadCount(inbox.id) || 0 }} não lidos</span></div>
            <h3 class="mt-4 font-bold text-n-slate-12">{{ inbox.name }}</h3>
            <p class="mt-1 truncate text-xs text-n-slate-9">{{ inbox.email || inbox.channel?.email || 'Conta de e-mail conectada' }}</p>
            <span class="mt-4 inline-flex items-center gap-1 text-sm font-semibold" style="color:#2563eb">Abrir caixa <span class="i-lucide-arrow-right size-4 transition group-hover:translate-x-1" /></span>
          </button>
        </div>
        <div v-else class="mt-5 rounded-2xl border border-dashed border-amber-300 bg-amber-50/60 p-10 text-center dark:bg-amber-950/10">
          <span class="i-lucide-mail-warning mx-auto block size-10 text-amber-500" />
          <h3 class="mt-3 font-bold text-n-slate-12">Nenhuma conta de e-mail configurada</h3>
          <p class="mx-auto mt-2 max-w-lg text-sm text-n-slate-10">Conecte uma caixa autorizada pelo cliente. O módulo não utiliza credenciais sem permissão do proprietário.</p>
          <button class="mt-5 rounded-xl bg-amber-500 px-4 py-2.5 text-sm font-semibold text-white" @click="openRoute('settings_inbox_list')">Configurar canal de e-mail</button>
        </div>
      </section>
    </div>
  </main>
</template>
