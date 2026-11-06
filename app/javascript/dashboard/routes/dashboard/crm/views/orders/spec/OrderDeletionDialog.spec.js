import { mount, flushPromises } from '@vue/test-utils';
import { reactive, ref } from 'vue';
import { createStore } from 'vuex';
import OrderDeletionDialog from '../OrderDeletionDialog.vue';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';

const context = vi.hoisted(() => ({ admin: null, route: null }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: context.admin }),
}));
vi.mock('vue-router', () => ({ useRoute: () => context.route }));
vi.mock('dashboard/api/crm/commercialCycle', () => ({
  salesOrdersAPI: { deletionPreview: vi.fn(), deleteWithDependencies: vi.fn() },
}));
const plan = {
  token: 'signed-preview',
  blocked: false,
  issues: [],
  confirmation: 'EXCLUIR PED-QA',
  counts: { delete: 2, preserve: 1 },
  rows: [
    {
      type: 'orders',
      id: 1,
      reference: 'PED-QA',
      action: 'delete',
      reason: 'Rascunho removível',
    },
    {
      type: 'payments',
      id: 9,
      reference: '#9',
      action: 'preserve',
      reason: 'Pagamento efetivado: preservar',
    },
  ],
  cancellation_requests: [],
};
let wrapper;
const button = text =>
  wrapper.findAll('button').find(b => b.text().includes(text));
const preview = async () => {
  wrapper.vm.open([{ id: 1, order_number: 'PED-QA' }]);
  await flushPromises();
  await wrapper.get('[name="deletion_reason"]').setValue('Duplicado QA');
  await button('Analisar vínculos').trigger('click');
  await flushPromises();
};
const confirm = async () => {
  await wrapper
    .get('[name="deletion_confirmation"]')
    .setValue(plan.confirmation);
  await wrapper.get('[name="deletion_confirmed"]').setValue(true);
  await button('Confirmar operação').trigger('click');
  await flushPromises();
};
beforeEach(() => {
  context.admin = ref(true);
  context.route = reactive({ params: { accountId: '1' } });
  vi.clearAllMocks();
  salesOrdersAPI.deletionPreview.mockResolvedValue({ data: plan });
  salesOrdersAPI.deleteWithDependencies.mockResolvedValue({
    data: { removed_ids: [1], retained_ids: [], receipt_ids: [7] },
  });
  HTMLDialogElement.prototype.showModal = function showModal() {
    this.open = true;
  };
  HTMLDialogElement.prototype.close = function close() {
    this.open = false;
  };
  wrapper = mount(OrderDeletionDialog, {
    global: {
      plugins: [
        createStore({
          getters: {
            getCurrentUser: () => ({ id: 1 }),
            getCurrentRole: () => 'administrator',
          },
        }),
      ],
      stubs: { teleport: true },
    },
  });
});
afterEach(() => wrapper.unmount());

it('shows an explicit scope and requires the reason, exact phrase and checkbox', async () => {
  await preview();
  expect(salesOrdersAPI.deletionPreview).toHaveBeenCalledWith({
    ids: [1],
    reason: 'Duplicado QA',
  });
  expect(wrapper.text()).toContain('Pagamento efetivado: preservar');
  expect(button('Confirmar operação').attributes('disabled')).toBeDefined();
  await wrapper.get('[name="deletion_confirmation"]').setValue('EXCLUIR');
  await wrapper.get('[name="deletion_confirmed"]').setValue(true);
  expect(button('Confirmar operação').attributes('disabled')).toBeDefined();
  await confirm();
  expect(salesOrdersAPI.deleteWithDependencies).toHaveBeenCalledWith({
    ids: [1],
    reason: 'Duplicado QA',
    confirmed: true,
    confirmation: plan.confirmation,
    preview_token: 'signed-preview',
  });
  expect(wrapper.emitted('completed')).toHaveLength(1);
  expect(wrapper.get('[role="status"]').text()).toContain('7');
});

it('does not allow an agent to open or execute an administrative operation', async () => {
  context.admin.value = false;
  wrapper.vm.open([{ id: 1, order_number: 'PED-QA' }]);
  await flushPromises();
  expect(wrapper.get('dialog').element.open).toBe(false);
  expect(salesOrdersAPI.deletionPreview).not.toHaveBeenCalled();
});

it('invalidates the scope when the reason changes', async () => {
  await preview();
  await wrapper.get('[name="deletion_reason"]').setValue('Outra justificativa');
  expect(wrapper.find('[name="deletion_confirmation"]').exists()).toBe(false);
  expect(salesOrdersAPI.deleteWithDependencies).not.toHaveBeenCalled();
});

it('blocks execution for unknown links and displays the retained scope', async () => {
  salesOrdersAPI.deletionPreview.mockResolvedValue({
    data: { ...plan, blocked: true, issues: ['Vínculo não classificado'] },
  });
  await preview();
  expect(wrapper.get('[role="alert"]').text()).toContain(
    'Vínculo não classificado'
  );
  await confirm();
  expect(salesOrdersAPI.deleteWithDependencies).not.toHaveBeenCalled();
});

it('requires a new preview after a stale-state response instead of resending', async () => {
  salesOrdersAPI.deleteWithDependencies.mockRejectedValue({
    response: { status: 409, data: { errors: ['Os vínculos mudaram'] } },
  });
  await preview();
  await confirm();
  expect(wrapper.get('[role="alert"]').text()).toContain('Os vínculos mudaram');
  expect(wrapper.find('[name="deletion_confirmation"]').exists()).toBe(false);
  expect(wrapper.emitted('completed')).toBeUndefined();
});

it('discards a late preview when the account changes', async () => {
  let resolve;
  salesOrdersAPI.deletionPreview.mockReturnValue(
    new Promise(r => {
      resolve = r;
    })
  );
  await preview();
  context.route.params.accountId = '2';
  await flushPromises();
  resolve({ data: plan });
  await flushPromises();
  expect(wrapper.get('dialog').element.open).toBe(false);
  expect(wrapper.find('[name="deletion_confirmation"]').exists()).toBe(false);
});

it('explains retention review without claiming that an external refund was made', async () => {
  salesOrdersAPI.deletionPreview.mockResolvedValue({
    data: { ...plan, cancellation_requests: ['PED-QA'] },
  });
  await preview();
  expect(wrapper.text()).toContain('Backoffice');
  expect(wrapper.text()).toContain('sem estorno');
});
