<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { crmControlClasses } from './crmControlClasses';

const route = useRoute();
const { t } = useI18n();
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, @intlify/vue-i18n/no-dynamic-keys */
const navigation = [
  { name: 'crm_dashboard', label: 'Visão Geral', icon: 'i-lucide-layout-dashboard', tone: 'blue' },
  { name: 'crm_indicators', label: 'Indicadores', icon: 'i-lucide-chart-no-axes-combined', tone: 'cyan' },
  { name: 'crm_leads', label: 'Leads', icon: 'i-lucide-user-round-plus', tone: 'violet' },
  { name: 'crm_deals', label: 'Negócios', icon: 'i-lucide-handshake', tone: 'orange' },
  { name: 'crm_funnel', label: 'Funil', icon: 'i-lucide-filter', tone: 'violet' },
  { name: 'crm_wallet', label: 'Minha Carteira', icon: 'i-lucide-briefcase-business', tone: 'blue' },
  { name: 'crm_activities', label: 'Atividades', icon: 'i-lucide-calendar-check-2', tone: 'orange' },
  { name: 'crm_calendar', label: 'Agenda', icon: 'i-lucide-calendar-days', tone: 'violet' },
  { name: 'crm_products', label: 'Produtos', icon: 'i-lucide-package', tone: 'green' },
  { name: 'crm_proposals', label: 'Propostas', icon: 'i-lucide-file-signature', tone: 'rose' },
  { name: 'crm_orders', label: 'Pedidos', icon: 'i-lucide-shopping-cart', tone: 'green' },
  { name: 'crm_contracts', label: 'Contratos', icon: 'i-lucide-file-check-2', tone: 'blue' },
  { name: 'crm_goals', label: 'Metas', icon: 'i-lucide-target', tone: 'cyan' },
  { name: 'crm_commissions', label: 'Comissões', icon: 'i-lucide-badge-dollar-sign', tone: 'orange' },
  { name: 'crm_backoffice', label: 'Backoffice', icon: 'i-lucide-settings-2', tone: 'green' },
  { name: 'crm_management', label: 'Gestão de Equipe', icon: 'i-lucide-users-round', tone: 'violet' },
  { name: 'crm_settings', label: 'Configurações', icon: 'i-lucide-settings', tone: 'blue' },
];

const activeTabClass = item => {
  if (route.name !== item.name) return '';
  const tones = {
    blue: '!border-transparent !bg-[#0669cc] !text-white !shadow-[0_8px_22px_rgba(8,124,240,.24)]',
    cyan: '!border-transparent !bg-[#0e7490] !text-white !shadow-[0_8px_22px_rgba(14,165,183,.22)]',
    violet: '!border-transparent !bg-[#7c3aed] !text-white !shadow-[0_8px_22px_rgba(124,58,237,.24)]',
    orange: '!border-transparent !bg-[#c2410c] !text-white !shadow-[0_8px_22px_rgba(249,115,22,.22)]',
    green: '!border-transparent !bg-[#047857] !text-white !shadow-[0_8px_22px_rgba(22,167,107,.22)]',
    rose: '!border-transparent !bg-[#be123c] !text-white !shadow-[0_8px_22px_rgba(232,59,106,.22)]',
  };
  return tones[item.tone] || tones.blue;
};

</script>

<template>
  <div :class="crmControlClasses" class="jrc-crm-shell flex h-full min-w-0 flex-1 flex-col bg-[#f7f9fc]">
    <header class="jrc-crm-top relative shrink-0 border-b border-n-weak bg-n-solid-2 px-3 pt-2">
      <nav :aria-label="t('CRM.HOMOLOGATION.MENU')" class="relative flex min-w-0 gap-1 overflow-x-auto pb-2">
        <RouterLink v-for="item in navigation" :key="item.name" :to="{ name: item.name }" class="jrc-crm-tab flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-lg border border-n-weak bg-n-solid-2 px-2.5 py-2 text-xs font-medium text-n-slate-11 shadow-[0_2px_8px_rgba(16,24,40,.04)] transition hover:-translate-y-0.5 hover:border-[#cfd7e4] hover:text-n-slate-12" :class="activeTabClass(item)">
          <span class="grid size-5 place-content-center rounded bg-black/[.035] text-current"><i class="size-4" :class="item.icon" /></span>
          {{ item.label }}
        </RouterLink>
      </nav>
    </header>
    <main class="min-w-0 bg-n-background jrc-visible-scrollbar min-h-0 flex-1 overflow-y-auto pb-24">
      <RouterView />
    </main>
  </div>
</template>

<style>
.jrc-crm-shell main > div > div { max-width: 1680px !important; }
.jrc-crm-shell article,
.jrc-crm-shell .shadow-sm { box-shadow: 0 8px 24px rgba(15, 23, 42, .055) !important; }
.jrc-crm-shell .rounded-2xl { border-radius: 16px !important; }
.jrc-crm-tab--active span { background: rgba(255,255,255,.14) !important; }
@media (max-width: 900px) {
  .jrc-crm-top { padding-left: 14px !important; padding-right: 14px !important; }
}
</style>
