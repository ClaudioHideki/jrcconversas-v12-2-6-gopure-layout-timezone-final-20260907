<script setup>
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import snakecaseKeys from 'snakecase-keys';
import { useContactCreation } from 'dashboard/composables/useContactCreation';
import { usePolicy } from 'dashboard/composables/usePolicy';
import API from 'dashboard/api/jrcCustomers';
import CreateNewContactDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateNewContactDialog.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CompanyPicker from 'dashboard/routes/dashboard/jrcCustomers/components/CompanyPicker.vue';
import CompanyEditor from 'dashboard/routes/dashboard/jrcCustomers/components/CompanyEditor.vue';
import { useCustomerMaster } from 'dashboard/routes/dashboard/jrcCustomers/useCustomerMaster';
import { errorMessage } from 'dashboard/routes/dashboard/jrcCustomers/copy';

const props = defineProps({
  companyId: { type: [Number, String], default: null },
  companyName: { type: String, default: '' },
});
const emit = defineEmits(['created', 'close']);
const { t } = useI18n();
const store = useStore();
const { checkPermissions } = usePolicy();
const { enabled, canAccess, accountId } = useCustomerMaster();
const canCreate = computed(
  () =>
    checkPermissions(['administrator', 'agent', 'contact_manage']) &&
    (!enabled.value || canAccess.value)
);
const contactDialog = ref(null);
const companyDialog = ref(null);
const companyEditor = ref(null);
const companyId = ref(props.companyId);
const companyName = ref(props.companyName);
const busy = ref(false);
const error = ref('');
const candidates = ref([]);
let selectInForm;
let mounted = true;
const identity = () => `${accountId.value}:${store.getters.getCurrentUser?.id}`;
const complete = contact => {
  if (!mounted || !canCreate.value) return;
  contactDialog.value.onSuccess();
  emit('created', contact);
};
const createNativeContact = useContactCreation(contactDialog, {
  allowed: () => mounted && canCreate.value,
  getIdentity: identity,
  onCreated: contact => emit('created', contact),
});
const createContact = async contact => {
  if (busy.value || !canCreate.value) return;
  if (!enabled.value) {
    await createNativeContact(contact);
    return;
  }
  const startedFor = identity();
  busy.value = true;
  error.value = '';
  candidates.value = [];
  try {
    const values = snakecaseKeys(contact, { deep: true });
    const { data } = await API.saveContact({
      name: values.name,
      email: values.email,
      phone_number: values.phone_number,
      company_id: companyId.value ?? (values.company_id || null),
      additional_attributes: {
        ...values.additional_attributes,
        company_name:
          companyName.value || values.additional_attributes?.company_name || '',
      },
    });
    if (mounted && identity() === startedFor && canCreate.value)
      complete(data.payload);
  } catch (err) {
    if (!mounted || identity() !== startedFor || !canCreate.value) return;
    candidates.value =
      err.response?.data?.code === 'POSSIBLE_DUPLICATE'
        ? err.response.data.candidates || []
        : [];
    error.value = candidates.value.length
      ? t('CRM.CREATION.DUPLICATE_CONTACT')
      : errorMessage(err);
  } finally {
    busy.value = false;
  }
};
const chooseCompany = (company, select) => {
  companyId.value = company?.id || null;
  companyName.value = company?.name || '';
  select(company || {});
};
const openCompany = select => {
  if (!canAccess.value || busy.value) return;
  selectInForm = select;
  companyDialog.value.open();
};
const companyCreated = company => {
  if (!mounted || !canAccess.value) return;
  chooseCompany(company, selectInForm);
  companyDialog.value.close();
};
const returnToContact = () => {
  if (mounted && canCreate.value) contactDialog.value?.open();
};
watch([accountId, () => store.getters.getCurrentUser?.id, canCreate], () => {
  companyDialog.value?.close();
  contactDialog.value?.dialogRef?.close();
  emit('close');
});
onMounted(() => {
  if (canCreate.value) contactDialog.value.open();
  else emit('close');
});
onBeforeUnmount(() => {
  mounted = false;
});
</script>

<template>
  <CreateNewContactDialog
    ref="contactDialog"
    nested-popover
    :saving="busy"
    :draft-scope="`crm:lead_contact:${props.companyId || 'standalone'}`"
    @create="createContact"
    @close="emit('close')"
  >
    <template v-if="enabled && canAccess" #company="scope">
      <div class="min-w-0 space-y-2">
        <CompanyPicker
          :model-value="companyId ?? scope.companyId"
          :disabled="busy"
          @selected="chooseCompany($event, scope.select)"
        />
        <button
          type="button"
          :disabled="busy"
          class="inline-flex min-h-10 items-center gap-2 rounded-lg px-2 text-sm font-semibold text-n-brand disabled:opacity-50"
          @click="openCompany(scope.select)"
        >
          <i class="i-lucide-building-2 size-4" aria-hidden="true" />
          {{ t('CRM.LEAD_FORM.CREATE_COMPANY') }}
        </button>
      </div>
    </template>
    <p v-if="error" role="alert" class="text-sm text-n-ruby-11">{{ error }}</p>
    <div
      v-if="candidates.length"
      class="max-h-48 overflow-auto rounded-lg border border-n-weak"
    >
      <button
        v-for="contact in candidates"
        :key="contact.id"
        type="button"
        class="block w-full p-3 text-left text-sm hover:bg-n-alpha-2"
        @click="complete(contact)"
      >
        {{ t('CRM.LEAD_FORM.USE_CONTACT') }}: {{ contact.name }} ·
        {{ contact.email || contact.phone_number }}
      </button>
    </div>
  </CreateNewContactDialog>
  <Dialog
    ref="companyDialog"
    nested-popover
    width="5xl"
    :use-form="false"
    :show-confirm-button="false"
    :show-cancel-button="false"
    :show-close-button="!companyEditor?.busy"
    :dismissible="!companyEditor?.busy"
    overflow-y-auto
    @close="returnToContact"
  >
    <CompanyEditor
      ref="companyEditor"
      @saved="companyCreated"
      @cancel="companyDialog.close()"
    />
  </Dialog>
</template>
