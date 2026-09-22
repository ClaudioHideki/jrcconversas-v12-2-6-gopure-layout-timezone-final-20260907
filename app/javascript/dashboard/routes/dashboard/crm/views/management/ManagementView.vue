<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, onMounted, ref } from 'vue';
import { managementAPI } from 'dashboard/api/crm';
import { useAlert } from 'dashboard/composables';

const rows = ref([]);
const loading = ref(false);
const period = ref('30');
const search = ref('');

const money = value =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format((Number(value) || 0) / 100);

const number = value =>
  new Intl.NumberFormat('pt-BR').format(Number(value) || 0);

const percentage = value =>
  `${new Intl.NumberFormat('pt-BR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
  }).format(Number(value) || 0)}%`;

const dateToISO = date => date.toISOString().slice(0, 10);

const range = () => {
  const end = new Date();
  const start = new Date();

  if (period.value === 'month') {
    start.setDate(1);
  } else if (period.value === 'year') {
    start.setMonth(0, 1);
  } else {
    start.setDate(start.getDate() - Number(period.value || 30));
  }

  return {
    start_date: dateToISO(start),
    end_date: dateToISO(end),
  };
};

const load = async () => {
  loading.value = true;

  try {
    const { data } = await managementAPI.list(range());
    rows.value = data || [];
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        error.response?.data?.message ||
        'Não foi possível carregar as métricas da equipe.'
    );
  } finally {
    loading.value = false;
  }
};

const filteredRows = computed(() => {
  const term = search.value.trim().toLowerCase();

  if (!term) return rows.value;

  return rows.value.filter(row =>
    [row.user?.name, row.user?.email]
      .filter(Boolean)
      .some(value => value.toLowerCase().includes(term))
  );
});

const totals = computed(() =>
  rows.value.reduce(
    (acc, row) => {
      const metrics = row.metrics || {};

      acc.openDeals += Number(
        metrics.open_deals_count ?? metrics.open_deals ?? 0
      );

      acc.won += Number(metrics.closed_won_count || 0);
      acc.lost += Number(metrics.closed_lost_count || 0);
      acc.pipeline += Number(metrics.pipeline_value_cents || 0);
      acc.revenue += Number(metrics.won_revenue_cents || 0);
      acc.overdue += Number(metrics.overdue_activities_count || 0);
      acc.stalled += Number(metrics.stalled_deals_count || 0);

      return acc;
    },
    {
      openDeals: 0,
      won: 0,
      lost: 0,
      pipeline: 0,
      revenue: 0,
      overdue: 0,
      stalled: 0,
    }
  )
);

const teamConversion = computed(() => {
  const closed = totals.value.won + totals.value.lost;

  if (!closed) return 0;

  return (totals.value.won / closed) * 100;
});

const teamAverageTicket = computed(() => {
  if (!totals.value.won) return 0;
  return totals.value.revenue / totals.value.won;
});

const initials = name =>
  (name || '?')
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(item => item[0])
    .join('')
    .toUpperCase();

const conversionTone = value => {
  const conversion = Number(value) || 0;

  if (conversion >= 70) return 'bg-emerald-50 text-emerald-700';
  if (conversion >= 40) return 'bg-blue-50 text-blue-700';
  if (conversion > 0) return 'bg-amber-50 text-amber-700';

  return 'bg-slate-100 text-slate-600';
};

const positionTone = index => {
  if (index === 0) return 'bg-amber-50 text-amber-600';
  if (index === 1) return 'bg-slate-100 text-slate-600';
  if (index === 2) return 'bg-orange-50 text-orange-600';

  return 'bg-blue-50 text-blue-600';
};

const sortedRows = computed(() =>
  [...filteredRows.value].sort(
    (a, b) =>
      Number(b.metrics?.won_revenue_cents || 0) -
      Number(a.metrics?.won_revenue_cents || 0)
  )
);

const periodLabel = computed(() => {
  const labels = {
    7: 'Últimos 7 dias',
    30: 'Últimos 30 dias',
    90: 'Últimos 90 dias',
    month: 'Este mês',
    year: 'Este ano',
  };

  return labels[period.value] || 'Período selecionado';
});

onMounted(load);
</script>

<template>
  <div class="h-full overflow-auto bg-[#f7faff] dark:bg-n-background p-5 sm:p-6">
    <!-- CABEÇALHO -->
    <header
      class="mb-6 flex flex-wrap items-center justify-between gap-4 rounded-3xl border border-white/70 bg-white/90 p-5 shadow-sm"
    >
      <div class="flex items-center gap-4">
        <span
          class="grid size-14 place-content-center rounded-2xl bg-gradient-to-br from-indigo-500 to-violet-600 text-white shadow-lg shadow-violet-100"
        >
          <i class="i-lucide-users-round size-7" />
        </span>

        <div>
          <div class="mb-1 flex flex-wrap items-center gap-2">
            <h2 class="text-2xl font-bold text-slate-900">
              Gestão de Equipe
            </h2>

            <span
              class="rounded-full bg-violet-50 px-2.5 py-1 text-xs font-semibold text-violet-700"
            >
              Comercial
            </span>
          </div>

          <p class="text-sm text-slate-500">
            Acompanhe desempenho, conversão, pipeline e resultados do time.
          </p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <select
          v-model="period"
          class="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-medium text-slate-700 outline-none focus:border-violet-400"
          @change="load"
        >
          <option value="7">Últimos 7 dias</option>
          <option value="30">Últimos 30 dias</option>
          <option value="90">Últimos 90 dias</option>
          <option value="month">Este mês</option>
          <option value="year">Este ano</option>
        </select>

        <button
          class="inline-flex items-center gap-2 rounded-xl border border-violet-200 bg-violet-50 px-4 py-2.5 text-sm font-semibold text-violet-700 transition hover:bg-violet-100"
          :disabled="loading"
          @click="load"
        >
          <i
            class="i-lucide-refresh-cw size-4"
            :class="{ 'animate-spin': loading }"
          />
          Atualizar
        </button>
      </div>
    </header>

    <!-- INDICADORES -->
    <section
      class="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4 2xl:grid-cols-6"
    >
      <article
        class="rounded-2xl border border-blue-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4 flex items-center justify-between">
          <span
            class="grid size-11 place-content-center rounded-xl bg-blue-50 text-blue-600"
          >
            <i class="i-lucide-briefcase-business size-5" />
          </span>
          <span class="text-xs font-medium text-slate-400">
            {{ periodLabel }}
          </span>
        </div>

        <p class="text-sm text-slate-500">Negócios abertos</p>
        <strong class="mt-1 block text-3xl font-bold text-blue-600">
          {{ number(totals.openDeals) }}
        </strong>
      </article>

      <article
        class="rounded-2xl border border-emerald-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4 flex items-center justify-between">
          <span
            class="grid size-11 place-content-center rounded-xl bg-emerald-50 text-emerald-600"
          >
            <i class="i-lucide-trophy size-5" />
          </span>
        </div>

        <p class="text-sm text-slate-500">Negócios ganhos</p>
        <strong class="mt-1 block text-3xl font-bold text-emerald-600">
          {{ number(totals.won) }}
        </strong>
      </article>

      <article
        class="rounded-2xl border border-violet-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4">
          <span
            class="grid size-11 place-content-center rounded-xl bg-violet-50 text-violet-600"
          >
            <i class="i-lucide-wallet-cards size-5" />
          </span>
        </div>

        <p class="text-sm text-slate-500">Pipeline aberto</p>
        <strong class="mt-1 block text-2xl font-bold text-violet-600">
          {{ money(totals.pipeline) }}
        </strong>
      </article>

      <article
        class="rounded-2xl border border-cyan-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4">
          <span
            class="grid size-11 place-content-center rounded-xl bg-cyan-50 text-cyan-600"
          >
            <i class="i-lucide-badge-dollar-sign size-5" />
          </span>
        </div>

        <p class="text-sm text-slate-500">Receita ganha</p>
        <strong class="mt-1 block text-2xl font-bold text-cyan-600">
          {{ money(totals.revenue) }}
        </strong>
      </article>

      <article
        class="rounded-2xl border border-amber-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4">
          <span
            class="grid size-11 place-content-center rounded-xl bg-amber-50 text-amber-600"
          >
            <i class="i-lucide-percent size-5" />
          </span>
        </div>

        <p class="text-sm text-slate-500">Conversão da equipe</p>
        <strong class="mt-1 block text-3xl font-bold text-amber-600">
          {{ percentage(teamConversion) }}
        </strong>
      </article>

      <article
        class="rounded-2xl border border-rose-100 bg-white p-5 shadow-sm"
      >
        <div class="mb-4 flex items-center justify-between">
          <span
            class="grid size-11 place-content-center rounded-xl bg-rose-50 text-rose-600"
          >
            <i class="i-lucide-triangle-alert size-5" />
          </span>

          <span
            v-if="totals.overdue"
            class="rounded-full bg-rose-50 px-2 py-1 text-xs font-bold text-rose-600"
          >
            Atenção
          </span>
        </div>

        <p class="text-sm text-slate-500">Atividades atrasadas</p>
        <strong class="mt-1 block text-3xl font-bold text-rose-600">
          {{ number(totals.overdue) }}
        </strong>
      </article>
    </section>

    <!-- RESUMO -->
    <section class="mb-6 grid gap-4 xl:grid-cols-3">
      <article
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <div class="flex items-center gap-3">
          <span
            class="grid size-10 place-content-center rounded-xl bg-emerald-50 text-emerald-600"
          >
            <i class="i-lucide-circle-dollar-sign size-5" />
          </span>

          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Ticket médio
            </p>
            <strong class="text-xl text-slate-900">
              {{ money(teamAverageTicket) }}
            </strong>
          </div>
        </div>
      </article>

      <article
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <div class="flex items-center gap-3">
          <span
            class="grid size-10 place-content-center rounded-xl bg-orange-50 text-orange-600"
          >
            <i class="i-lucide-circle-x size-5" />
          </span>

          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Negócios perdidos
            </p>
            <strong class="text-xl text-slate-900">
              {{ number(totals.lost) }}
            </strong>
          </div>
        </div>
      </article>

      <article
        class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
      >
        <div class="flex items-center gap-3">
          <span
            class="grid size-10 place-content-center rounded-xl bg-fuchsia-50 text-fuchsia-600"
          >
            <i class="i-lucide-hourglass size-5" />
          </span>

          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-400">
              Negócios parados
            </p>
            <strong class="text-xl text-slate-900">
              {{ number(totals.stalled) }}
            </strong>
          </div>
        </div>
      </article>
    </section>

    <!-- TABELA -->
    <section
      class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"
    >
      <div
        class="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 p-4"
      >
        <div>
          <h3 class="font-bold text-slate-900">
            Desempenho por vendedor
          </h3>
          <p class="text-xs text-slate-500">
            Comparativo individual do time no período selecionado.
          </p>
        </div>

        <label class="relative w-full max-w-sm">
          <i
            class="i-lucide-search absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400"
          />

          <input
            v-model="search"
            class="w-full rounded-xl border border-slate-200 bg-slate-50 py-2.5 pl-10 pr-4 text-sm outline-none transition focus:border-violet-400 focus:bg-white"
            placeholder="Buscar vendedor..."
          />
        </label>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full min-w-[1250px] text-sm">
          <thead
            class="border-b border-slate-200 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"
          >
            <tr>
              <th class="p-4">Posição</th>
              <th class="p-4">Vendedor</th>
              <th class="p-4 text-center">Abertos</th>
              <th class="p-4 text-center">Ganhos</th>
              <th class="p-4 text-center">Perdidos</th>
              <th class="p-4 text-right">Pipeline</th>
              <th class="p-4 text-right">Receita ganha</th>
              <th class="p-4 text-center">Conversão</th>
              <th class="p-4 text-right">Ticket médio</th>
              <th class="p-4 text-center">Atrasadas</th>
              <th class="p-4 text-center">Parados</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-slate-100">
            <tr v-if="loading">
              <td colspan="11" class="p-14 text-center text-slate-500">
                <i
                  class="i-lucide-loader-circle mx-auto mb-3 size-7 animate-spin text-violet-500"
                />
                Carregando métricas da equipe...
              </td>
            </tr>

            <tr
              v-for="(row, index) in sortedRows"
              v-else
              :key="row.user?.id"
              class="transition hover:bg-slate-50/80"
            >
              <td class="p-4">
                <span
                  :class="positionTone(index)"
                  class="inline-grid size-8 place-content-center rounded-full text-xs font-bold"
                >
                  {{ index + 1 }}
                </span>
              </td>

              <td class="p-4">
                <div class="flex items-center gap-3">
                  <span
                    class="grid size-10 shrink-0 place-content-center rounded-full bg-gradient-to-br from-blue-500 to-violet-500 text-xs font-bold text-white shadow-sm"
                  >
                    {{ initials(row.user?.name) }}
                  </span>

                  <div>
                    <strong class="block text-slate-900">
                      {{ row.user?.name || 'Sem nome' }}
                    </strong>
                    <span class="text-xs text-slate-500">
                      {{ row.user?.email || '—' }}
                    </span>
                  </div>
                </div>
              </td>

              <td class="p-4 text-center font-semibold text-blue-600">
                {{
                  number(
                    row.metrics?.open_deals_count ??
                      row.metrics?.open_deals ??
                      0
                  )
                }}
              </td>

              <td class="p-4 text-center font-semibold text-emerald-600">
                {{ number(row.metrics?.closed_won_count) }}
              </td>

              <td class="p-4 text-center font-semibold text-rose-600">
                {{ number(row.metrics?.closed_lost_count) }}
              </td>

              <td class="p-4 text-right font-semibold text-violet-600">
                {{ money(row.metrics?.pipeline_value_cents) }}
              </td>

              <td class="p-4 text-right font-bold text-cyan-700">
                {{ money(row.metrics?.won_revenue_cents) }}
              </td>

              <td class="p-4 text-center">
                <span
                  :class="conversionTone(row.metrics?.conversion_rate)"
                  class="inline-flex rounded-full px-2.5 py-1 text-xs font-bold"
                >
                  {{ percentage(row.metrics?.conversion_rate) }}
                </span>
              </td>

              <td class="p-4 text-right font-medium text-slate-700">
                {{
                  money(
                    row.metrics?.average_ticket_cents ??
                      row.metrics?.avg_ticket_cents
                  )
                }}
              </td>

              <td class="p-4 text-center">
                <span
                  :class="
                    row.metrics?.overdue_activities_count
                      ? 'bg-rose-50 text-rose-700'
                      : 'bg-emerald-50 text-emerald-700'
                  "
                  class="rounded-full px-2.5 py-1 text-xs font-bold"
                >
                  {{ number(row.metrics?.overdue_activities_count) }}
                </span>
              </td>

              <td class="p-4 text-center">
                <span
                  :class="
                    row.metrics?.stalled_deals_count
                      ? 'bg-amber-50 text-amber-700'
                      : 'bg-slate-100 text-slate-600'
                  "
                  class="rounded-full px-2.5 py-1 text-xs font-bold"
                >
                  {{ number(row.metrics?.stalled_deals_count) }}
                </span>
              </td>
            </tr>

            <tr v-if="!loading && !sortedRows.length">
              <td colspan="11" class="p-14 text-center">
                <span
                  class="mx-auto mb-3 grid size-12 place-content-center rounded-2xl bg-violet-50 text-violet-500"
                >
                  <i class="i-lucide-users size-6" />
                </span>

                <strong class="block text-slate-700">
                  Nenhum vendedor encontrado
                </strong>

                <span class="mt-1 block text-sm text-slate-500">
                  Não existem métricas disponíveis para este período.
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>