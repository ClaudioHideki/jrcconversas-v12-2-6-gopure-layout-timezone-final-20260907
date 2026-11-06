<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import OrderDeletionDialog from './OrderDeletionDialog.vue';
import { calculateOrderMetrics } from './orderMetrics';
import ApprovalGateBadge from 'dashboard/routes/dashboard/approvals/ApprovalGateBadge.vue';
import { computed, onMounted, ref, watch } from 'vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useRoute, useRouter } from 'vue-router';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';
import { useAlert } from 'dashboard/composables';
import { crmControlClasses } from '../../crmControlClasses';

const route = useRoute();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const router = useRouter();
const rows = ref([]);
const listCommercialFlow = ref(null);
const loading = ref(false);
const selected = ref(null);
const approvalDialog = ref(null);
const approvalOrder = ref(null);
const approving = ref(false);
const approvalError = ref('');
const approvalLabel = computed(() =>
  t(
    approvalOrder.value?.commercial_flow === 'simple'
      ? 'CRM.ORDERS.APPROVE_ACTIVATE'
      : 'CRM.ORDERS.APPROVE'
  )
);
const openApproval = () => {
  if (!isAdmin.value || !selected.value?.approval?.can_approve) return;
  approvalOrder.value = selected.value;
  approvalError.value = '';
  approvalDialog.value.open();
};
const approveOrder = async () => {
  if (approving.value || !isAdmin.value || !approvalOrder.value) return;
  const accountId = route.params.accountId;
  const id = approvalOrder.value.id;
  approving.value = true;
  approvalError.value = '';
  try {
    const { data } = await salesOrdersAPI.approve(id);
    if (route.params.accountId !== accountId) return;
    rows.value = rows.value.map(row => (row.id === id ? data : row));
    if (selected.value?.id === id) selected.value = data;
    approvalDialog.value.close();
    useAlert(
      t(
        data.commercial_status === 'active'
          ? 'CRM.ORDERS.ACTIVATION_SUCCESS'
          : 'CRM.ORDERS.APPROVAL_SUCCESS'
      )
    );
  } catch (error) {
    if (route.params.accountId !== accountId) return;
    approvalError.value =
      error.response?.data?.errors?.join(', ') ||
      t(
        error.response?.data?.code
          ? 'CRM.ORDERS.APPROVAL_GATE_BLOCKED'
          : 'CRM.ORDERS.APPROVAL_ERROR'
      );
  } finally {
    approving.value = false;
  }
};
const saving = ref(false);
const search = ref('');
const statusFilter = ref('all');
const ownerFilter = ref('all');
const customerFilter = ref('all');
const periodFilter = ref('all');
const view = ref('list');
const page = ref(1);
const perPage = ref(10);
const selectedIds = ref([]);
const selectedOnly = ref(false);
const deletionDialog = ref(null);

const removalRows = ref([]);
const removalDialog = ref(null);
const removalReason = ref('');
const removalConfirmed = ref(false);
const removing = ref(false);
const removalError = ref('');
const requestRemoval = orders => {
  removalRows.value = orders;
  removalReason.value = '';
  removalConfirmed.value = false;
  removalError.value = '';
  removalDialog.value.open();
};
const removeOrders = async () => {
  if (
    removing.value ||
    !removalReason.value.trim() ||
    !removalConfirmed.value ||
    !isAdmin.value
  )
    return;
  const accountId = route.params.accountId;
  removing.value = true;
  removalError.value = '';
  try {
    const ids = removalRows.value.map(row => row.id);
    await salesOrdersAPI.remove({
      ids,
      reason: removalReason.value,
      confirmed: removalConfirmed.value,
    });
    if (route.params.accountId !== accountId) return;
    rows.value = rows.value.filter(row => !ids.includes(row.id));
    selectedIds.value = selectedIds.value.filter(id => !ids.includes(id));
    removalRows.value = [];
    approvalOrder.value = null;
    approvalError.value = '';
    approvalDialog.value?.close();
    removalDialog.value.close();
  } catch (error) {
    removalError.value =
      error.response?.data?.errors?.join(' ') || t('CRM.ORDERS.REMOVE_ERROR');
  } finally {
    removing.value = false;
  }
};
const editingItems = ref(false);
const draftItems = ref([]);

const money = value =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    (Number(value) || 0) / 100
  );
const dateLabel = value =>
  value ? new Intl.DateTimeFormat('pt-BR').format(new Date(value)) : '—';
const statusLabel = status =>
  ({
    active: t('CRM.ORDERS.ACTIVE'),
    draft: 'Rascunho',
    pending: 'Pendente',
    approved: 'Aprovado',
    separating: 'Em implantação',
    invoiced: 'Faturado',
    shipped: 'Em entrega',
    completed: 'Ativo',
    canceled: 'Cancelado',
  })[status] || status;
const statusTone = status =>
  ({
    active: 'bg-n-teal-3 text-n-teal-11',
    draft: 'bg-n-slate-3 text-n-slate-12',
    pending: 'bg-amber-50 text-amber-700',
    approved: 'bg-emerald-50 text-emerald-700',
    separating: 'bg-blue-50 text-blue-700',
    invoiced: 'bg-violet-50 text-violet-700',
    shipped: 'bg-cyan-50 text-cyan-700',
    completed: 'bg-emerald-50 text-emerald-700',
    canceled: 'bg-red-50 text-red-700',
  })[status] || 'bg-n-slate-3 text-n-slate-12';
const originLabel = origin =>
  ({
    proposal_deal: 'Proposta / Negócio',
    direct_sale: 'Venda direta',
    renewal: 'Renovação',
    expansion: 'Upgrade / Expansão',
  })[origin] ||
  origin ||
  '—';
const customerName = row =>
  row.contact?.name || row.snapshot?.customer_name || 'Cliente não informado';
const orderDate = row => row.created_at;
const orderStatus = row => row.commercial_status || row.status;
const simpleListFlow = computed(() =>
  listCommercialFlow.value
    ? listCommercialFlow.value === 'simple'
    : rows.value.length > 0 &&
      rows.value.every(row => row.commercial_flow === 'simple')
);
const kanbanStages = computed(() =>
  simpleListFlow.value
    ? ['draft', 'pending', 'active', 'canceled']
    : [
        'pending',
        'approved',
        'separating',
        'completed',
        ...(rows.value.some(row => row.commercial_flow === 'simple')
          ? ['active']
          : []),
      ]
);

const owners = computed(() => [
  ...new Map(
    rows.value.filter(r => r.owner).map(r => [r.owner.id, r.owner])
  ).values(),
]);
const customers = computed(() =>
  [
    ...new Map(
      rows.value.map(r => [customerName(r), customerName(r)])
    ).values(),
  ].sort()
);
const periodMatch = row => {
  if (periodFilter.value === 'all') return true;
  const d = new Date(orderDate(row));
  const now = new Date();
  if (periodFilter.value === 'month')
    return (
      d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
    );
  if (periodFilter.value === 'quarter')
    return (
      d.getFullYear() === now.getFullYear() &&
      Math.floor(d.getMonth() / 3) === Math.floor(now.getMonth() / 3)
    );
  if (periodFilter.value === 'year')
    return d.getFullYear() === now.getFullYear();
  return true;
};
const filtered = computed(() =>
  rows.value.filter(
    row =>
      (!selectedOnly.value || selectedIds.value.includes(row.id)) &&
      periodMatch(row) &&
      (statusFilter.value === 'all' ||
        orderStatus(row) === statusFilter.value) &&
      (ownerFilter.value === 'all' ||
        String(row.owner?.id) === String(ownerFilter.value)) &&
      (customerFilter.value === 'all' ||
        customerName(row) === customerFilter.value) &&
      (!search.value ||
        `${row.order_number} ${customerName(row)} ${row.deal?.title || ''} ${row.proposal?.proposal_number || ''}`
          .toLowerCase()
          .includes(search.value.toLowerCase()))
  )
);
const pagedRows = computed(() =>
  filtered.value.slice(
    (page.value - 1) * perPage.value,
    page.value * perPage.value
  )
);
const pageCount = computed(() =>
  Math.max(1, Math.ceil(filtered.value.length / perPage.value))
);
watch(
  [
    search,
    statusFilter,
    ownerFilter,
    customerFilter,
    periodFilter,
    perPage,
    selectedOnly,
  ],
  () => {
    page.value = 1;
  }
);
watch(pageCount, count => {
  page.value = Math.min(page.value, count);
});
const kpiRows = computed(() => filtered.value);
const previousPeriodRows = computed(() => {
  if (periodFilter.value === 'all') return [];
  const now = new Date();
  let start;
  let end;
  if (periodFilter.value === 'month') {
    start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
  } else if (periodFilter.value === 'quarter') {
    const currentQuarter = Math.floor(now.getMonth() / 3);
    start = new Date(now.getFullYear(), (currentQuarter - 1) * 3, 1);
    end = new Date(now.getFullYear(), currentQuarter * 3, 0, 23, 59, 59);
  } else {
    start = new Date(now.getFullYear() - 1, 0, 1);
    end = new Date(now.getFullYear() - 1, 11, 31, 23, 59, 59);
  }
  return rows.value.filter(row => {
    const d = new Date(orderDate(row));
    return (
      d >= start &&
      d <= end &&
      (statusFilter.value === 'all' ||
        orderStatus(row) === statusFilter.value) &&
      (ownerFilter.value === 'all' ||
        String(row.owner?.id) === String(ownerFilter.value)) &&
      (customerFilter.value === 'all' ||
        customerName(row) === customerFilter.value) &&
      (!search.value ||
        `${row.order_number} ${customerName(row)} ${row.deal?.title || ''} ${row.proposal?.proposal_number || ''}`
          .toLowerCase()
          .includes(search.value.toLowerCase()))
    );
  });
});
const totals = computed(() => calculateOrderMetrics(kpiRows.value));
const statusCounts = computed(() =>
  (simpleListFlow.value
    ? ['draft', 'pending', 'active', 'canceled']
    : [
        'draft',
        'pending',
        'approved',
        'separating',
        'invoiced',
        'shipped',
        'completed',
        'canceled',
        ...(rows.value.some(row => row.commercial_flow === 'simple')
          ? ['active']
          : []),
      ]
  )
    .map(status => ({
      status,
      count: kpiRows.value.filter(r => orderStatus(r) === status).length,
    }))
    .filter(item => item.count > 0)
);
const previousTotals = computed(() =>
  calculateOrderMetrics(previousPeriodRows.value)
);
const salesDelta = computed(() =>
  previousTotals.value.total
    ? Math.round(
        ((totals.value.total - previousTotals.value.total) /
          previousTotals.value.total) *
          100
      )
    : null
);
const countDelta = computed(() =>
  previousTotals.value.count
    ? Math.round(
        ((totals.value.count - previousTotals.value.count) /
          previousTotals.value.count) *
          100
      )
    : null
);
const statusDonut = computed(() => {
  const palette = [
    '#94a3b8',
    '#f59e0b',
    '#22c55e',
    '#3b82f6',
    '#8b5cf6',
    '#06b6d4',
    '#10b981',
    '#ef4444',
  ];
  const total = Math.max(
    1,
    statusCounts.value.reduce((sum, item) => sum + item.count, 0)
  );
  let cursor = 0;
  const stops = statusCounts.value.map((item, index) => {
    const start = cursor;
    cursor += (item.count / total) * 100;
    return `${palette[index]} ${start}% ${cursor}%`;
  });
  return { background: `conic-gradient(${stops.join(',')})` };
});
const latest = computed(() =>
  [...rows.value]
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 4)
);
const upcoming = computed(() =>
  rows.value
    .filter(
      r =>
        r.snapshot?.activation_date &&
        !['completed', 'canceled'].includes(r.status)
    )
    .sort((a, b) =>
      String(a.snapshot.activation_date).localeCompare(
        String(b.snapshot.activation_date)
      )
    )
    .slice(0, 4)
);

const detailLoading = ref(false);
const open = async row => {
  editingItems.value = false;
  selected.value = row;
  detailLoading.value = true;
  router.replace({ query: { ...route.query, orderId: row.id } });
  try {
    const { data } = await salesOrdersAPI.show(row.id);
    if (String(selected.value?.id) === String(row.id)) selected.value = data;
  } catch (e) {
    useAlert('Não foi possível carregar o detalhe do pedido.');
  } finally {
    detailLoading.value = false;
  }
};
const load = async () => {
  const accountId = route.params.accountId;
  listCommercialFlow.value = null;
  loading.value = true;
  try {
    const response = await salesOrdersAPI.list();
    if (route.params.accountId !== accountId) return;
    listCommercialFlow.value =
      response.headers?.['x-jrc-commercial-flow'] || null;
    rows.value = response.data || [];
    selectedIds.value = selectedIds.value.filter(id =>
      rows.value.some(row => row.id === id)
    );
    const q = route.query.orderId;
    if (q) {
      const row = rows.value.find(x => String(x.id) === String(q));
      if (row) await open(row);
    }
  } finally {
    loading.value = false;
  }
};
const deletionCompleted = async data => {
  selectedIds.value = selectedIds.value.filter(
    id => !data.removed_ids.includes(id)
  );
  if (data.removed_ids.includes(selected.value?.id)) selected.value = null;
  await load();
};
const close = () => {
  selected.value = null;
  const q = { ...route.query };
  delete q.orderId;
  router.replace({ query: q });
};
const changeStatus = async status => {
  if (!selected.value) return;
  saving.value = true;
  try {
    const { data } = await salesOrdersAPI.update(selected.value.id, {
      sales_order: { status },
    });
    selected.value = data;
    await load();
    useAlert('Status do pedido atualizado.');
  } catch (e) {
    useAlert(
      e.response?.data?.errors?.join(', ') ||
        'Não foi possível atualizar o pedido.'
    );
  } finally {
    saving.value = false;
  }
};
const startItemEdit = () => {
  draftItems.value = selected.value.items.map(item => ({ ...item }));
  editingItems.value = true;
};
const recalculateItem = item => {
  item.one_time_cents = Math.max(
    Math.round(Number(item.unit_cents || 0) * Number(item.quantity || 1)) -
      Number(item.discount_cents || 0),
    0
  );
};
const saveItems = async () => {
  if (!selected.value) return;
  saving.value = true;
  try {
    const { data } = await salesOrdersAPI.update(selected.value.id, {
      sales_order: { items: draftItems.value },
    });
    selected.value = data;
    editingItems.value = false;
    await load();
    useAlert('Itens e indicadores recalculados.');
  } catch (e) {
    useAlert(
      e.response?.data?.errors?.join(', ') ||
        'Não foi possível atualizar os itens.'
    );
  } finally {
    saving.value = false;
  }
};
const newContract = () =>
  router.push({
    name: 'crm_contract_new',
    params: { accountId: route.params.accountId },
    query: { orderId: selected.value.id },
  });
const downloadPdf = async (row, event) => {
  event?.stopPropagation();
  try {
    const { data } = await salesOrdersAPI.pdf(row.id);
    const url = URL.createObjectURL(data);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${row.order_number}.pdf`;
    a.click();
    URL.revokeObjectURL(url);
  } catch (e) {
    useAlert('Não foi possível gerar o PDF do pedido.');
  }
};
const clearFilters = () => {
  periodFilter.value = 'all';
  statusFilter.value = 'all';
  ownerFilter.value = 'all';
  customerFilter.value = 'all';
  search.value = '';
  page.value = 1;
};
const exportCsv = () => {
  const header = [
    'Pedido',
    'Cliente',
    'Negócio',
    'Proposta',
    'Responsável',
    'Valor',
    'MRR',
    'Data',
    'Status',
  ];
  const body = filtered.value.map(r => [
    r.order_number,
    customerName(r),
    r.deal?.title || '',
    r.proposal?.proposal_number || '',
    r.owner?.name || '',
    (Number(r.total_cents || 0) / 100).toFixed(2),
    (Number(r.monthly_cents || 0) / 100).toFixed(2),
    dateLabel(orderDate(r)),
    statusLabel(orderStatus(r)),
  ]);
  const csv = [header, ...body]
    .map(line =>
      line.map(v => `"${String(v).replaceAll('"', '""')}"`).join(';')
    )
    .join('\n');
  const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'vendas-pedidos.csv';
  a.click();
  URL.revokeObjectURL(url);
};
const newOrder = () =>
  router.push({
    name: 'crm_order_new',
    params: { accountId: route.params.accountId },
  });
const allOnPageSelected = computed(
  () =>
    pagedRows.value.length > 0 &&
    pagedRows.value.every(r => selectedIds.value.includes(r.id))
);
const togglePage = () => {
  if (allOnPageSelected.value)
    selectedIds.value = selectedIds.value.filter(
      id => !pagedRows.value.some(r => r.id === id)
    );
  else
    selectedIds.value = [
      ...new Set([...selectedIds.value, ...pagedRows.value.map(r => r.id)]),
    ];
};
onMounted(load);
watch(
  () => route.params.accountId,
  () => {
    rows.value = [];
    selectedIds.value = [];
    selected.value = null;
    selectedOnly.value = false;
    removalRows.value = [];
    load();
  }
);
</script>

<template>
  <div
    class="h-full overflow-auto bg-n-background dark:bg-n-background p-4 sm:p-6"
  >
    <header class="mb-5 flex flex-wrap items-center justify-between gap-4">
      <div class="flex items-center gap-3">
        <span
          class="grid size-12 place-content-center rounded-2xl bg-blue-600 text-white shadow-lg shadow-blue-100"
          ><i class="i-lucide-shopping-cart size-6"
        /></span>
        <div>
          <h2 class="text-2xl font-bold text-n-slate-12">Vendas / Pedidos</h2>
          <p class="text-sm text-n-slate-11">
            Gerencie os pedidos, acompanhe o faturamento e o progresso das
            implantações.
          </p>
        </div>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class="min-h-11 rounded-xl border border-solid border-n-weak bg-n-solid-2 px-4 py-2.5 text-n-slate-12"
          :disabled="!selectedOnly && !selectedIds.length"
          @click="selectedOnly = !selectedOnly"
        >
          {{
            t(selectedOnly ? 'CRM.ORDERS.SHOW_ALL' : 'CRM.ORDERS.SHOW_SELECTED')
          }}
          ({{ selectedIds.length }})
        </button>
        <button
          v-if="isAdmin"
          type="button"
          class="min-h-11 rounded-xl border border-solid border-n-ruby-6 bg-n-ruby-2 px-4 py-2.5 text-n-ruby-11 disabled:opacity-50"
          :disabled="!selectedIds.length || selectedIds.length > 100"
          @click="
            requestRemoval(rows.filter(row => selectedIds.includes(row.id)))
          "
        >
          <i class="i-lucide-trash-2 mr-2 inline-block size-4 align-middle" />{{
            t('CRM.ORDERS.REMOVE_SELECTED')
          }}
        </button>
        <button
          v-if="isAdmin"
          type="button"
          :disabled="!selectedIds.length || selectedIds.length > 20"
          class="min-h-11 rounded-xl border border-n-ruby-7 px-4 py-2 text-n-ruby-11 disabled:opacity-50"
          @click="
            deletionDialog.open(
              rows.filter(row => selectedIds.includes(row.id))
            )
          "
        >
          {{ t('CRM.ORDER_DELETION.TITLE') }}
        </button>
        <button
          class="rounded-xl border bg-n-solid-2 px-4 py-2.5 font-semibold"
          @click="exportCsv"
        >
          <i class="i-lucide-download mr-2 inline size-4" />Exportar</button
        ><button
          class="rounded-xl border bg-n-solid-2 px-4 py-2.5 font-semibold"
          :disabled="loading"
          @click="load"
        >
          Atualizar</button
        ><button
          class="rounded-xl bg-blue-600 px-5 py-2.5 font-semibold text-white shadow-lg shadow-blue-100"
          @click="newOrder"
        >
          + Novo pedido
        </button>
      </div>
    </header>
    <Dialog
      ref="approvalDialog"
      type="edit"
      :title="approvalLabel"
      :description="t('CRM.ORDERS.APPROVAL_HELP')"
      :confirm-button-label="t('CRM.ORDERS.CONFIRM_APPROVAL')"
      :cancel-button-label="t('CRM.ORDERS.CANCEL_APPROVAL')"
      :disable-confirm-button="approving"
      :dismissible="!approving"
      :is-loading="approving"
      @confirm="approveOrder"
    >
      <p v-if="approvalOrder" class="text-sm text-n-slate-12">
        <strong>{{ approvalOrder.order_number }}</strong> —
        {{ customerName(approvalOrder) }} —
        {{ money(approvalOrder.total_cents) }}
      </p>
      <p v-if="approvalError" role="alert" class="mt-3 text-sm text-n-ruby-11">
        {{ approvalError }}
      </p>
    </Dialog>
    <OrderDeletionDialog ref="deletionDialog" @completed="deletionCompleted" />
    <Dialog
      ref="removalDialog"
      :title="t('CRM.ORDERS.REMOVE_SELECTED')"
      :description="t('CRM.ORDERS.REMOVAL_HELP')"
      :confirm-button-label="t('CRM.ORDERS.CONFIRM_REMOVE')"
      :disable-confirm-button="
        !removalConfirmed || !removalReason.trim() || removing
      "
      :dismissible="!removing"
      :is-loading="removing"
      @confirm="removeOrders"
    >
      <ul class="max-h-48 overflow-auto text-sm text-n-slate-12">
        <li v-for="row in removalRows" :key="row.id" class="py-1">
          {{ row.order_number }} — {{ customerName(row) }} —
          {{ money(row.total_cents) }}
        </li>
      </ul>
      <label class="mt-4 block text-sm text-n-slate-12"
        >{{ t('CRM.ORDERS.REASON') }}
        <textarea
          v-model="removalReason"
          name="removal_reason"
          required
          rows="3"
          class="mt-2 w-full rounded-lg border border-n-weak bg-n-solid-2 p-3"
        />
      </label>
      <label class="mt-4 flex items-start gap-2 text-sm text-n-slate-12">
        <input
          v-model="removalConfirmed"
          name="removal_confirmed"
          type="checkbox"
          required
          class="mt-1"
        />{{ t('CRM.ORDERS.CONFIRMATION') }}
      </label>
      <p v-if="removalError" role="alert" class="mt-3 text-sm text-n-ruby-11">
        {{ removalError }}
      </p>
    </Dialog>

    <section class="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
      <article
        v-for="card in [
          [
            'Vendas no período',
            money(totals.total),
            `${totals.active} pedidos aprovados/ativos`,
            'i-lucide-shopping-cart',
          ],
          [
            'Receita vendida',
            money(totals.total),
            'Somente pedidos aprovados/ativos',
            'i-lucide-circle-dollar-sign',
          ],
          [
            simpleListFlow ? 'Pedidos no período' : 'MRR vendido',
            simpleListFlow ? totals.count : money(totals.mrr),
            simpleListFlow ? 'Todos os status' : 'Receita recorrente mensal',
            'i-lucide-chart-no-axes-combined',
          ],
          [
            'Aguardando aprovação',
            totals.approval,
            'Pedidos pendentes',
            'i-lucide-clock-3',
          ],
          [
            'Em implantação',
            totals.implementation,
            'Operação em andamento',
            'i-lucide-settings',
          ],
          [
            'Ativas',
            totals.active,
            'Aprovados comercialmente',
            'i-lucide-circle-check-big',
          ],
        ]"
        :key="card[0]"
        class="rounded-2xl border border-slate-200 bg-n-solid-2 p-4 shadow-sm"
      >
        <div class="mb-3 flex items-start justify-between">
          <p class="text-xs font-medium text-n-slate-11">{{ card[0] }}</p>
          <span
            class="grid size-9 place-content-center rounded-xl bg-blue-50 text-blue-600"
          >
            <i class="size-4" :class="card[3]" />
          </span>
        </div>
        <strong class="block text-xl text-n-slate-12">{{ card[1] }}</strong
        ><small class="text-n-slate-11">{{ card[2] }}</small>
      </article>
    </section>

    <section class="mb-5 grid gap-4 xl:grid-cols-[360px_minmax(0,1fr)]">
      <article
        class="rounded-2xl border border-slate-200 bg-n-solid-2 p-5 shadow-sm"
      >
        <div class="flex items-start justify-between">
          <div>
            <h3 class="font-bold text-n-slate-12">Pedidos por status</h3>
            <p class="text-xs text-n-slate-11">
              Distribuição do período e filtros atuais.
            </p>
          </div>
          <span
            class="rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700"
            >{{ totals.count }} pedidos</span
          >
        </div>
        <div class="mt-5 flex items-center gap-5">
          <div
            class="relative size-36 shrink-0 rounded-full"
            :style="statusDonut"
          >
            <div
              class="absolute inset-5 grid place-content-center rounded-full bg-n-solid-2 text-center"
            >
              <strong class="text-2xl text-n-slate-12">{{
                totals.count
              }}</strong>
              <span class="text-[11px] text-n-slate-11">total</span>
            </div>
          </div>
          <div class="grid flex-1 grid-cols-2 gap-x-3 gap-y-2 text-xs">
            <div
              v-for="item in statusCounts"
              :key="item.status"
              class="flex items-center justify-between gap-2"
            >
              <span class="truncate text-n-slate-11">{{
                statusLabel(item.status)
              }}</span>
              <b class="text-n-slate-12">{{ item.count }}</b>
            </div>
          </div>
        </div>
      </article>
      <article
        class="rounded-2xl border border-slate-200 bg-n-solid-2 p-5 shadow-sm"
      >
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-bold text-n-slate-12">
              Comparativo com período anterior
            </h3>
            <p class="text-xs text-n-slate-11">
              Os KPIs respeitam período, cliente, responsável, status e busca.
            </p>
          </div>
          <i class="i-lucide-chart-no-axes-combined size-5 text-blue-600" />
        </div>
        <div class="mt-5 grid gap-3 sm:grid-cols-3">
          <div class="rounded-xl bg-blue-50 p-4">
            <p class="text-xs text-blue-700">Receita atual</p>
            <strong class="mt-1 block text-xl text-n-slate-12">{{
              money(totals.total)
            }}</strong>
            <span
              v-if="salesDelta !== null"
              class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold"
              :class="
                salesDelta >= 0
                  ? 'bg-emerald-100 text-emerald-700'
                  : 'bg-red-100 text-red-700'
              "
              >{{ salesDelta >= 0 ? '+' : '' }}{{ salesDelta }}%</span
            >
            <span v-else class="mt-2 block text-xs text-n-slate-11">
              Sem base anterior
            </span>
          </div>
          <div class="rounded-xl bg-violet-50 p-4">
            <p class="text-xs text-violet-700">Pedidos atuais</p>
            <strong class="mt-1 block text-xl text-n-slate-12">{{
              totals.count
            }}</strong>
            <span
              v-if="countDelta !== null"
              class="mt-2 inline-flex rounded-full px-2 py-1 text-xs font-semibold"
              :class="
                countDelta >= 0
                  ? 'bg-emerald-100 text-emerald-700'
                  : 'bg-red-100 text-red-700'
              "
              >{{ countDelta >= 0 ? '+' : '' }}{{ countDelta }}%</span
            >
            <span v-else class="mt-2 block text-xs text-n-slate-11">
              Sem base anterior
            </span>
          </div>
          <div class="rounded-xl bg-emerald-50 p-4">
            <p class="text-xs text-emerald-700">Conversão</p>
            <strong class="mt-1 block text-xl text-n-slate-12"
              >{{ totals.conversion }}%</strong
            >
            <p class="mt-2 text-xs text-n-slate-11">
              Base filtrada em tempo real
            </p>
          </div>
        </div>
      </article>
    </section>

    <section
      class="mb-4 grid gap-3 rounded-2xl border border-slate-200 bg-n-solid-2 p-4 shadow-sm md:grid-cols-2 xl:grid-cols-[180px_180px_220px_220px_1fr_auto]"
    >
      <select
        v-model="periodFilter"
        class="rounded-xl border border-slate-200 px-3 py-2.5"
      >
        <option value="all">Todos os períodos</option>
        <option value="month">Este mês</option>
        <option value="quarter">Este trimestre</option>
        <option value="year">Este ano</option>
      </select>
      <select
        v-model="statusFilter"
        class="rounded-xl border border-slate-200 px-3 py-2.5"
      >
        <option value="all">Todos os status</option>
        <option v-for="s in statusCounts" :key="s.status" :value="s.status">
          {{ statusLabel(s.status) }}
        </option>
      </select>
      <select
        v-model="ownerFilter"
        class="rounded-xl border border-slate-200 px-3 py-2.5"
      >
        <option value="all">Todos os responsáveis</option>
        <option v-for="o in owners" :key="o.id" :value="o.id">
          {{ o.name }}
        </option>
      </select>
      <select
        v-model="customerFilter"
        class="rounded-xl border border-slate-200 px-3 py-2.5"
      >
        <option value="all">Todos os clientes</option>
        <option v-for="c in customers" :key="c" :value="c">{{ c }}</option>
      </select>
      <div class="relative">
        <i
          class="i-lucide-search absolute left-3 top-3 size-4 text-n-slate-11"
        /><input
          v-model="search"
          class="w-full rounded-xl border border-slate-200 py-2.5 pl-10 pr-3"
          placeholder="Buscar por número, cliente ou negócio..."
        />
      </div>
      <button
        class="rounded-xl border border-slate-200 px-4 py-2.5"
        @click="clearFilters"
      >
        <i class="i-lucide-filter-x mr-2 inline size-4" />Limpar filtros
      </button>
    </section>

    <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_290px]">
      <div class="min-w-0 space-y-4">
        <section
          class="overflow-hidden rounded-2xl border border-slate-200 bg-n-solid-2 shadow-sm"
        >
          <div
            class="flex flex-wrap items-center justify-between gap-3 border-b p-4"
          >
            <div>
              <h3 class="font-bold text-n-slate-12">Pedidos</h3>
              <p class="text-xs text-n-slate-11">
                Lista de pedidos gerados no CRM.
              </p>
            </div>
            <div class="flex rounded-xl bg-n-slate-3 p-1">
              <button
                class="rounded-lg px-3 py-1.5 text-sm"
                :class="
                  view === 'list'
                    ? 'bg-blue-600 text-white shadow'
                    : 'text-n-slate-11'
                "
                @click="view = 'list'"
              >
                ☷ Lista</button
              ><button
                class="rounded-lg px-3 py-1.5 text-sm"
                :class="
                  view === 'kanban'
                    ? 'bg-blue-600 text-white shadow'
                    : 'text-n-slate-11'
                "
                @click="view = 'kanban'"
              >
                ▥ Kanban
              </button>
            </div>
          </div>
          <div v-if="view === 'list'" class="overflow-x-auto">
            <table class="w-full min-w-[1050px] text-sm">
              <thead
                class="bg-n-slate-2 text-left text-[11px] uppercase text-n-slate-11"
              >
                <tr>
                  <th class="p-3">
                    <input
                      type="checkbox"
                      :checked="allOnPageSelected"
                      @change="togglePage"
                    />
                  </th>
                  <th class="p-3">Nº do pedido</th>
                  <th class="p-3">Cliente</th>
                  <th class="p-3">Negócio</th>
                  <th class="p-3">Proposta</th>
                  <th class="p-3">Responsável</th>
                  <th class="p-3">Valor</th>
                  <th v-if="!simpleListFlow" class="p-3">MRR</th>
                  <th class="p-3">Data</th>
                  <th class="p-3">Status</th>
                  <th class="p-3">Ações</th>
                </tr>
              </thead>
              <tbody class="divide-y">
                <tr v-if="loading">
                  <td colspan="11" class="p-10 text-center">Carregando…</td>
                </tr>
                <tr
                  v-for="row in pagedRows"
                  :key="row.id"
                  class="cursor-pointer hover:bg-blue-50/40"
                  @click="open(row)"
                >
                  <td class="p-3" @click.stop>
                    <input
                      v-model="selectedIds"
                      type="checkbox"
                      :value="row.id"
                    />
                  </td>
                  <td class="p-3 font-semibold text-blue-700">
                    <button
                      type="button"
                      class="underline underline-offset-2"
                      @click.stop="open(row)"
                    >
                      {{ row.order_number }}
                    </button>
                  </td>
                  <td class="p-3">
                    <b>{{ customerName(row) }}</b>
                    <p class="text-xs text-n-slate-11">
                      {{ row.contact?.email || '' }}
                    </p>
                  </td>
                  <td class="p-3">{{ row.deal?.title || 'Pedido direto' }}</td>
                  <td class="p-3 text-blue-600">
                    {{ row.proposal?.proposal_number || '—' }}
                  </td>
                  <td class="p-3">{{ row.owner?.name || '—' }}</td>
                  <td class="p-3 font-semibold">
                    {{ money(row.total_cents) }}
                  </td>
                  <td v-if="!simpleListFlow" class="p-3">
                    {{ money(row.monthly_cents) }}
                  </td>
                  <td class="p-3">{{ dateLabel(orderDate(row)) }}</td>
                  <td class="p-3">
                    <span
                      class="rounded-full px-2.5 py-1 text-xs font-semibold"
                      :class="statusTone(orderStatus(row))"
                      >{{ statusLabel(orderStatus(row)) }}</span
                    >
                  </td>
                  <td class="p-3">
                    <button
                      type="button"
                      class="mr-2 rounded-lg border p-2"
                      title="Ver pedido"
                      aria-label="Ver pedido"
                      @click.stop="open(row)"
                    >
                      <i class="i-lucide-file-text size-4" />
                    </button>
                    <button
                      title="Baixar PDF"
                      aria-label="Baixar PDF"
                      class="rounded-lg border p-2"
                      @click.stop="downloadPdf(row, $event)"
                    >
                      <i class="i-lucide-file-down size-4" />
                    </button>
                    <button
                      v-if="isAdmin"
                      type="button"
                      :aria-label="t('CRM.ORDER_DELETION.TITLE')"
                      class="rounded-lg border border-n-ruby-7 p-2 text-n-ruby-11"
                      @click.stop="deletionDialog.open([row])"
                    >
                      <i class="i-lucide-list-tree size-4" />
                    </button>
                    <button
                      v-if="isAdmin"
                      type="button"
                      class="ml-2 rounded-lg border border-n-ruby-7 p-2 text-n-ruby-11"
                      :title="t('CRM.ORDERS.REMOVE')"
                      :aria-label="t('CRM.ORDERS.REMOVE')"
                      @click.stop="requestRemoval([row])"
                    >
                      <i class="i-lucide-trash-2 size-4" />
                    </button>
                  </td>
                </tr>
                <tr v-if="!loading && !pagedRows.length">
                  <td colspan="11" class="p-10 text-center text-n-slate-11">
                    Nenhum pedido encontrado.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div
            v-else
            class="grid min-w-[1000px] grid-cols-4 gap-3 overflow-x-auto bg-n-slate-2 p-4"
          >
            <section
              v-for="st in kanbanStages"
              :key="st"
              class="rounded-2xl bg-n-slate-3 p-3"
            >
              <h3 class="mb-3 font-bold">
                {{ statusLabel(st) }}
                <span class="float-right text-xs text-n-slate-11">{{
                  filtered.filter(r => orderStatus(r) === st).length
                }}</span>
              </h3>
              <article
                v-for="row in filtered.filter(r => orderStatus(r) === st)"
                :key="row.id"
                class="mb-2 cursor-pointer rounded-xl border bg-n-solid-2 p-3 shadow-sm"
                @click="open(row)"
              >
                <b class="text-blue-700">{{ row.order_number }}</b>
                <p class="text-sm">{{ customerName(row) }}</p>
                <p class="mt-2 font-semibold">{{ money(row.total_cents) }}</p>
              </article>
            </section>
          </div>
          <footer
            v-if="view === 'list'"
            class="flex flex-wrap items-center justify-between gap-3 border-t p-4 text-sm text-n-slate-11"
          >
            <span
              >Mostrando {{ filtered.length ? (page - 1) * perPage + 1 : 0 }} a
              {{ Math.min(page * perPage, filtered.length) }} de
              {{ filtered.length }} pedidos</span
            >
            <div class="flex items-center gap-2">
              <button
                class="rounded-lg border px-3 py-1.5"
                :disabled="page <= 1"
                @click="page--"
              >
                ‹</button
              ><button
                v-for="p in pageCount"
                :key="p"
                class="size-8 rounded-lg border"
                :class="p === page && 'bg-blue-600 text-white'"
                @click="page = p"
              >
                {{ p }}</button
              ><button
                class="rounded-lg border px-3 py-1.5"
                :disabled="page >= pageCount"
                @click="page++"
              >
                ›</button
              ><select v-model="perPage" class="rounded-lg border px-2 py-1.5">
                <option :value="10">10 por página</option>
                <option :value="20">20 por página</option>
                <option :value="50">50 por página</option>
              </select>
            </div>
          </footer>
        </section>

        <div class="grid gap-4 lg:grid-cols-2">
          <section class="rounded-2xl border bg-n-solid-2 p-4 shadow-sm">
            <div class="mb-3 flex items-center justify-between">
              <h3 class="font-bold">Últimos pedidos criados</h3>
              <span class="text-xs text-blue-600">Atualizado pelo CRM</span>
            </div>
            <div
              v-for="row in latest"
              :key="row.id"
              class="flex cursor-pointer items-center justify-between border-t py-3 text-sm"
              @click="open(row)"
            >
              <div>
                <b class="text-blue-600">{{ row.order_number }}</b
                ><span class="ml-3">{{ customerName(row) }}</span>
              </div>
              <span
                class="rounded-full px-2 py-1 text-xs"
                :class="statusTone(orderStatus(row))"
                >{{ statusLabel(orderStatus(row)) }}</span
              >
            </div>
            <p
              v-if="!latest.length"
              class="py-6 text-center text-sm text-n-slate-11"
            >
              Nenhum pedido criado.
            </p>
          </section>
          <section class="rounded-2xl border bg-n-solid-2 p-4 shadow-sm">
            <div class="mb-3 flex items-center justify-between">
              <h3 class="font-bold">Próximas implantações</h3>
              <span class="text-xs text-blue-600">Previsão de ativação</span>
            </div>
            <div
              v-for="row in upcoming"
              :key="row.id"
              class="flex cursor-pointer items-center justify-between border-t py-3 text-sm"
              @click="open(row)"
            >
              <div>
                <b>{{ customerName(row) }}</b>
                <p class="text-xs text-n-slate-11">{{ row.order_number }}</p>
              </div>
              <div class="text-right">
                <b>{{ dateLabel(row.snapshot.activation_date) }}</b>
                <p class="text-xs text-blue-600">
                  {{ statusLabel(orderStatus(row)) }}
                </p>
              </div>
            </div>
            <p
              v-if="!upcoming.length"
              class="py-6 text-center text-sm text-n-slate-11"
            >
              Nenhuma implantação programada.
            </p>
          </section>
        </div>
      </div>

      <aside class="space-y-4">
        <section class="rounded-2xl border bg-n-solid-2 p-4 shadow-sm">
          <h3 class="font-bold">Resumo do período</h3>
          <div class="mt-3 space-y-2 text-sm">
            <p class="flex justify-between">
              <span>Pedidos</span><b>{{ totals.count }}</b>
            </p>
            <p class="flex justify-between">
              <span>Receita de pedidos ativos</span
              ><b>{{ money(totals.total) }}</b>
            </p>
            <p v-if="!simpleListFlow" class="flex justify-between">
              <span>MRR</span><b>{{ money(totals.mrr) }}</b>
            </p>
            <p class="flex justify-between">
              <span>Ticket médio</span><b>{{ money(totals.ticket) }}</b>
            </p>
            <p class="flex justify-between">
              <span>Taxa de conversão</span><b>{{ totals.conversion }}%</b>
            </p>
          </div>
        </section>
        <section class="rounded-2xl border bg-n-solid-2 p-4 shadow-sm">
          <h3 class="font-bold">Pedidos por status</h3>
          <div class="mt-4 space-y-2">
            <div
              v-for="s in statusCounts"
              :key="s.status"
              class="flex items-center justify-between text-sm"
            >
              <span class="flex items-center gap-2"
                ><i class="size-2 rounded-full bg-blue-500" />{{
                  statusLabel(s.status)
                }}</span
              ><b>{{ s.count }}</b>
            </div>
          </div>
        </section>
        <section class="rounded-2xl border bg-n-solid-2 p-4 shadow-sm">
          <h3 class="font-bold">Ações rápidas</h3>
          <div class="mt-3 grid gap-2">
            <button
              class="rounded-xl border px-3 py-2 text-left text-sm hover:bg-n-slate-2"
              @click="newOrder"
            >
              ＋ Novo pedido</button
            ><button
              class="rounded-xl border px-3 py-2 text-left text-sm"
              @click="
                router.push({
                  name: 'crm_proposals',
                  params: { accountId: route.params.accountId },
                })
              "
            >
              ⇩ Importar de proposta</button
            ><button
              class="rounded-xl border px-3 py-2 text-left text-sm"
              @click="
                router.push({
                  name: 'crm_indicators',
                  params: { accountId: route.params.accountId },
                })
              "
            >
              ▥ Relatório de vendas</button
            ><button
              class="rounded-xl border px-3 py-2 text-left text-sm"
              @click="statusFilter = 'separating'"
            >
              ⚙ Pedidos em implantação</button
            ><button
              class="rounded-xl border px-3 py-2 text-left text-sm"
              @click="statusFilter = 'invoiced'"
            >
              ▤ Faturas geradas
            </button>
          </div>
        </section>
      </aside>
    </div>

    <Teleport to="body">
      <div
        v-if="selected"
        :class="crmControlClasses"
        class="fixed inset-0 z-[90] flex justify-end bg-black/40"
        @click.self="close"
      >
        <aside
          class="h-full w-full max-w-2xl overflow-auto bg-n-solid-2 p-6 shadow-2xl"
        >
          <div class="flex justify-between">
            <div>
              <p class="text-xs uppercase text-n-slate-11">
                Visão geral do pedido
              </p>
              <h3 class="text-xl font-bold">{{ selected.order_number }}</h3>
              <ApprovalGateBadge
                resource-key="crm.order_price"
                :resource-id="selected.id"
              />
              <p class="text-sm text-n-slate-11">
                {{ customerName(selected) }}
              </p>
            </div>
            <button class="i-lucide-x size-5" title="Fechar" @click="close" />
          </div>
          <p v-if="detailLoading" class="mt-3 text-sm" role="status">
            Carregando detalhe…
          </p>
          <div class="mt-5 flex gap-2">
            <button
              class="rounded-lg border border-red-200 px-3 py-2 text-red-700"
              @click="downloadPdf(selected)"
            >
              Gerar PDF</button
            ><button class="rounded-lg border px-3 py-2" @click="newContract">
              Gerar contrato
            </button>
          </div>
          <div
            class="mt-6 grid grid-cols-2 gap-3 rounded-xl border p-4 text-sm"
          >
            <div>
              <span class="text-xs text-n-slate-11">Total</span
              ><strong class="block text-lg">{{
                money(selected.total_cents)
              }}</strong>
            </div>
            <div>
              <span class="text-xs text-n-slate-11">MRR</span
              ><strong class="block"
                >{{ money(selected.monthly_cents) }}/mês</strong
              >
            </div>
            <div>
              <span class="text-xs text-n-slate-11">Origem</span
              ><strong class="block">{{
                originLabel(selected.order_origin)
              }}</strong>
            </div>
            <div>
              <span class="text-xs text-n-slate-11">Proposta</span
              ><strong class="block">{{
                selected.proposal
                  ? `${selected.proposal.proposal_number} v${selected.proposal.version_number || selected.proposal_version || 1}`
                  : 'Sem proposta'
              }}</strong>
            </div>
            <div>
              <span class="text-xs text-n-slate-11">Criado por</span
              ><strong class="block">{{
                selected.created_by?.name || selected.owner?.name || '—'
              }}</strong>
            </div>
            <div>
              <span class="text-xs text-n-slate-11">Ativação</span
              ><strong class="block">{{
                dateLabel(selected.snapshot?.activation_date)
              }}</strong>
            </div>
          </div>
          <section
            class="mt-4 grid grid-cols-2 gap-3 rounded-xl border p-4 text-sm"
          >
            <div>
              <span>Empresa</span
              ><strong class="block">{{
                selected.company?.name || '—'
              }}</strong>
            </div>
            <div>
              <span>Negócio</span
              ><strong class="block">{{
                selected.deal?.title || 'Pedido direto'
              }}</strong>
            </div>
            <div>
              <span>Responsável</span
              ><strong class="block">{{ selected.owner?.name || '—' }}</strong>
            </div>
            <div>
              <span>Contato</span
              ><strong class="block">{{
                selected.contact?.email || selected.contact?.phone_number || '—'
              }}</strong>
            </div>
            <div>
              <span>Condição de pagamento</span
              ><strong class="block">{{
                selected.payment_condition || '—'
              }}</strong>
            </div>
            <div>
              <span>Forma de pagamento</span
              ><strong class="block">{{
                selected.payment_method || '—'
              }}</strong>
            </div>
            <div>
              <span>Entrada</span
              ><strong class="block">{{
                money(selected.down_payment_cents)
              }}</strong>
            </div>
            <div>
              <span>Parcelas</span
              ><strong class="block">{{
                selected.installments_count || '—'
              }}</strong>
            </div>
            <div>
              <span>Criado em</span
              ><strong class="block">{{
                dateLabel(selected.created_at)
              }}</strong>
            </div>
            <div>
              <span>Atualizado em</span
              ><strong class="block">{{
                dateLabel(selected.updated_at)
              }}</strong>
            </div>
            <div class="col-span-2">
              <span>Implantação / observações</span>
              <p>
                {{
                  selected.snapshot?.operation_notes || selected.notes || '—'
                }}
              </p>
            </div>
          </section>
          <section class="mt-4 rounded-xl border p-4">
            <div class="flex items-center justify-between">
              <h4 class="font-semibold">Itens</h4>
              <button
                v-if="!editingItems"
                class="rounded-lg border px-3 py-1.5 text-sm"
                @click="startItemEdit"
              >
                Editar itens
              </button>
            </div>
            <template v-if="editingItems">
              <div
                v-for="item in draftItems"
                :key="item.id"
                class="mt-3 grid grid-cols-2 gap-2 rounded-lg border p-3 text-sm md:grid-cols-5"
              >
                <label class="col-span-2"
                  >Item<input
                    v-model="item.name"
                    class="mt-1 w-full rounded-lg border p-2" /></label
                ><label
                  >Quantidade<input
                    v-model.number="item.quantity"
                    type="number"
                    min="0.001"
                    step="0.001"
                    class="mt-1 w-full rounded-lg border p-2"
                    @change="recalculateItem(item)" /></label
                ><label
                  >Valor unitário<input
                    v-model.number="item.unit_cents"
                    type="number"
                    min="0"
                    class="mt-1 w-full rounded-lg border p-2"
                    @change="recalculateItem(item)" /></label
                ><label
                  >Desconto<input
                    v-model.number="item.discount_cents"
                    type="number"
                    min="0"
                    class="mt-1 w-full rounded-lg border p-2"
                    @change="recalculateItem(item)" /></label
                ><label
                  >Valor líquido<input
                    v-model.number="item.one_time_cents"
                    type="number"
                    min="0"
                    class="mt-1 w-full rounded-lg border p-2" /></label
                ><label
                  >MRR<input
                    v-model.number="item.recurring_cents"
                    type="number"
                    min="0"
                    class="mt-1 w-full rounded-lg border p-2"
                /></label>
              </div>
              <div class="mt-3 flex justify-end gap-2">
                <button
                  class="rounded-lg border px-3 py-2"
                  :disabled="saving"
                  @click="editingItems = false"
                >
                  Cancelar</button
                ><button
                  class="rounded-lg bg-blue-600 px-3 py-2 font-semibold text-white"
                  :disabled="saving"
                  @click="saveItems"
                >
                  Salvar e recalcular
                </button>
              </div> </template
            ><template v-else>
              <div
                v-for="i in selected.items"
                :key="i.id"
                class="flex justify-between border-t py-2 text-sm"
              >
                <span>{{ i.name }} × {{ i.quantity }}</span
                ><span
                  ><b>{{ money(i.one_time_cents) }}</b> · MRR
                  {{ money(i.recurring_cents) }}</span
                >
              </div>
            </template>
          </section>
          <section class="mt-4 rounded-xl border p-4">
            <h4 class="font-semibold">Fluxo do pedido</h4>
            <p
              v-if="selected.commercial_flow === 'simple'"
              class="mt-2 text-sm"
            >
              {{ t('CRM.ORDERS.SIMPLE_FLOW') }}
            </p>
            <p v-else class="mt-2 text-sm">
              Pendente → Aprovado → Em implantação → Faturado → Em entrega →
              Ativo
            </p>
            <p class="mt-2 font-semibold">
              {{ statusLabel(orderStatus(selected)) }}
            </p>
            <p
              v-if="selected.commercial_flow === 'simple'"
              class="mt-2 text-sm text-n-slate-11"
            >
              {{ t('CRM.ORDERS.SIMPLE_FLOW_HELP') }}
            </p>
            <div class="mt-3 flex flex-wrap gap-2">
              <button
                v-if="isAdmin"
                type="button"
                class="min-h-11 rounded-lg border border-n-ruby-7 px-4 py-2 text-n-ruby-11"
                @click="deletionDialog.open([selected])"
              >
                {{ t('CRM.ORDER_DELETION.TITLE') }}
              </button>
              <button
                v-if="isAdmin && selected.approval?.can_approve"
                class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-n-brand px-4 py-2.5 font-semibold text-white sm:w-auto"
                :disabled="saving || detailLoading || approving"
                @click="openApproval"
              >
                <i class="i-lucide-check-circle size-5" aria-hidden="true" />
                {{
                  t(
                    selected.commercial_flow === 'simple'
                      ? 'CRM.ORDERS.APPROVE_ACTIVATE'
                      : 'CRM.ORDERS.APPROVE'
                  )
                }}
              </button>
              <button
                v-for="status in (selected.allowed_statuses || []).filter(
                  status =>
                    selected.commercial_flow !== 'simple' ||
                    ['pending', 'canceled'].includes(status)
                )"
                :key="status"
                class="rounded-lg border px-3 py-2"
                :disabled="saving || detailLoading"
                @click="changeStatus(status)"
              >
                {{
                  status === 'canceled'
                    ? 'Cancelar pedido'
                    : statusLabel(status)
                }}
              </button>
            </div>
          </section>
          <section class="mt-4 rounded-xl border p-4">
            <h4 class="font-semibold">Histórico / timeline</h4>
            <ol class="mt-3 space-y-3">
              <li
                v-for="event in selected.history || []"
                :key="event.id"
                class="border-l-2 pl-3 text-sm"
              >
                <strong>{{
                  event.metadata?.decision === 'approved'
                    ? t(
                        selected.commercial_flow === 'simple'
                          ? 'CRM.ORDERS.ACTIVATION_SUCCESS'
                          : 'CRM.ORDERS.APPROVAL_SUCCESS'
                      )
                    : event.event_type
                }}</strong>
                <p
                  v-if="
                    event.metadata?.decision === 'approved' && event.actor?.name
                  "
                >
                  {{ t('CRM.ORDERS.APPROVED_BY', { name: event.actor.name }) }}
                </p>
                <p>{{ new Date(event.created_at).toLocaleString('pt-BR') }}</p>
                <p v-if="event.metadata?.before?.status">
                  {{ statusLabel(event.metadata.before.status) }} →
                  {{ statusLabel(event.metadata.after?.status) }}
                </p>
              </li>
            </ol>
            <p v-if="!selected.history?.length" class="mt-2 text-sm">
              Nenhum evento registrado.
            </p>
          </section>
        </aside>
      </div>
    </Teleport>
  </div>
</template>
