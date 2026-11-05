<script setup>
import { computed, reactive, ref } from 'vue';
import { usePolicy } from 'dashboard/composables/usePolicy';
import LeadContactCreateDialog from './LeadContactCreateDialog.vue';
import { useFormDraft } from '../../helpers/useFormDraft';
import CompanyPicker from 'dashboard/routes/dashboard/jrcCustomers/components/CompanyPicker.vue';
import { useCustomerMaster } from 'dashboard/routes/dashboard/jrcCustomers/useCustomerMaster';
const props = defineProps({ contact: { type: Object, default: null } });
const emit = defineEmits(['close', 'created']);
const { enabled: hasCustomerMaster, canAccess } = useCustomerMaster();
const { checkPermissions } = usePolicy();
const canCreateContact = computed(
  () =>
    checkPermissions(['administrator', 'agent', 'contact_manage']) &&
    (!hasCustomerMaster.value || canAccess.value)
);
const showContactForm = ref(false);
const companyId = ref(null);
import { crmControlClasses } from '../../crmControlClasses';

import { useI18n } from 'vue-i18n';
import { leadsAPI } from 'dashboard/api/crm';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const saving = ref(false);
const errorMessage = ref('');
const selectedContact = ref(props.contact);
const linkedContact = computed(() => selectedContact.value);
companyId.value =
  linkedContact.value?.company_id || linkedContact.value?.companyId || null;
const form = reactive({
  name: linkedContact.value?.name || '',
  company_name:
    linkedContact.value?.company?.name ||
    linkedContact.value?.companyName ||
    linkedContact.value?.additionalAttributes?.companyName ||
    linkedContact.value?.additional_attributes?.company_name ||
    '',
  email: linkedContact.value?.email || '',
  phone:
    linkedContact.value?.phoneNumber || linkedContact.value?.phone_number || '',
  source: '',
  status: 'new',
  temperature: 'warm',
  notes: '',
});

const activeDraft = ref(true);
const initialForm = { ...form };
const initialCompany = companyId.value;
const draft = useFormDraft(
  'crm:new_lead:' + (props.contact?.id || 'standalone'),
  {
    active: activeDraft,
    snapshot: () => ({
      form: { ...form },
      company_id: companyId.value,
      contact: selectedContact.value,
    }),
    restore: value => {
      Object.assign(form, value.form || {});
      companyId.value = value.company_id || null;
      selectedContact.value = value.contact || props.contact;
    },
    reset: () => {
      Object.assign(form, initialForm);
      companyId.value = initialCompany;
      selectedContact.value = props.contact;
    },
  }
);
draft.open();
const close = () => {
  if (!saving.value) {
    draft.flush();
    activeDraft.value = false;
    emit('close');
  }
};
const save = async () => {
  const savingDraftKey = draft.key.value;
  if (saving.value) return;
  errorMessage.value = '';
  saving.value = true;
  try {
    const { data, status } = await leadsAPI.create({
      lead: {
        ...form,
        ...(hasCustomerMaster.value ? { company_id: companyId.value } : {}),
        ...(linkedContact.value ? { contact_id: linkedContact.value.id } : {}),
      },
    });
    useAlert(
      status === 201 ? t('CRM.LEAD_FORM.SUCCESS') : t('CRM.LEAD_FORM.EXISTING')
    );
    if (!draft.complete(savingDraftKey)) return;
    activeDraft.value = false;
    emit('created', data);
  } catch (error) {
    const errors = error.response?.data?.errors;
    errorMessage.value =
      [409, 422].includes(error.response?.status) && Array.isArray(errors)
        ? errors.join(', ')
        : t('CRM.LEAD_FORM.ERROR');
  } finally {
    saving.value = false;
  }
};
const contactCreated = value => {
  selectedContact.value = value;
  form.name = value.name;
  form.email = value.email || '';
  form.phone = value.phone_number || value.phoneNumber || '';
  companyId.value = value.company_id || value.companyId || null;
  form.company_name =
    value.company_name ||
    value.company?.name ||
    value.additional_attributes?.company_name ||
    '';
  showContactForm.value = false;
};
</script>

<template>
  <Teleport to="body">
    <div
      :class="crmControlClasses"
      class="fixed inset-0 z-[80] flex items-center justify-center bg-black/55 p-4"
      @click.self="close"
      @keydown.esc="close"
    >
      <form
        role="dialog"
        aria-modal="true"
        aria-labelledby="lead-create-title"
        class="max-h-[90vh] w-full max-w-lg space-y-4 overflow-y-auto rounded-2xl border border-n-weak bg-n-solid-2 p-6 shadow-2xl"
        @submit.prevent="save"
      >
        <div class="flex items-center justify-between">
          <h3 id="lead-create-title" class="text-xl font-bold text-n-slate-12">
            {{ t('CRM.LEAD_FORM.TITLE') }}
          </h3>
          <button
            type="button"
            :disabled="saving"
            :aria-label="t('CRM.LEAD_FORM.CLOSE')"
            class="rounded-lg p-2 text-n-slate-11"
            @click="close"
          >
            <i class="i-lucide-x size-5" />
          </button>
        </div>
        <p
          v-if="linkedContact"
          class="rounded-xl bg-n-blue-3 p-3 text-sm text-n-blue-11"
        >
          {{
            t('CRM.LEAD_FORM.LINKED_CONTACT', {
              name: linkedContact.name,
              id: linkedContact.id,
            })
          }}
        </p>
        <label class="block text-sm text-n-slate-11">
          <span class="block">{{ t('CRM.LEAD_FORM.NAME') }}</span>
          <input
            v-model="form.name"
            name="name"
            required
            class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          />
        </label>
        <div class="grid gap-3 sm:grid-cols-2">
          <div class="min-w-0 space-y-2">
            <CompanyPicker
              v-if="hasCustomerMaster"
              v-model="companyId"
              :disabled="saving"
              @selected="
                value => {
                  form.company_name = value?.name || '';
                }
              "
            />
            <label v-else class="text-sm text-n-slate-11">
              <span class="block">{{ t('CRM.LEAD_FORM.COMPANY') }}</span
              ><input
                v-model="form.company_name"
                name="company_name"
                class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
            /></label>
            <button
              v-if="canCreateContact && !linkedContact"
              type="button"
              :disabled="saving"
              class="inline-flex min-h-10 items-center gap-2 rounded-lg px-2 text-sm font-semibold text-n-brand disabled:opacity-50"
              @click="showContactForm = true"
            >
              <i class="i-lucide-user-round-plus size-4" aria-hidden="true" />
              {{ t('CRM.LEAD_FORM.CREATE_CUSTOMER') }}
            </button>
          </div>
          <label class="text-sm text-n-slate-11">
            <span class="block">{{ t('CRM.LEAD_FORM.SOURCE') }}</span
            ><input
              v-model="form.source"
              name="source"
              class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          /></label>
          <label class="text-sm text-n-slate-11">
            <span class="block">{{ t('CRM.LEAD_FORM.EMAIL') }}</span
            ><input
              v-model="form.email"
              name="email"
              type="email"
              class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          /></label>
          <label class="text-sm text-n-slate-11">
            <span class="block">{{ t('CRM.LEAD_FORM.PHONE') }}</span
            ><input
              v-model="form.phone"
              name="phone"
              type="tel"
              :placeholder="t('CRM.LEAD_FORM.PHONE_HINT')"
              class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          /></label>
        </div>
        <label class="block text-sm text-n-slate-11">
          <span class="block">{{ t('CRM.LEAD_FORM.STATUS') }}</span>
          <select
            v-model="form.status"
            name="status"
            class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          >
            <option value="new">{{ t('CRM.INDICATORS.STATUS.NEW') }}</option>
            <option value="in_contact">
              {{ t('CRM.INDICATORS.STATUS.IN_CONTACT') }}
            </option>
            <option value="qualified">
              {{ t('CRM.INDICATORS.STATUS.QUALIFIED') }}
            </option>
          </select>
        </label>
        <label class="block text-sm text-n-slate-11">
          <span class="block">{{ t('CRM.LEAD_FORM.NOTES') }}</span
          ><textarea
            v-model="form.notes"
            name="notes"
            rows="3"
            class="mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 px-3 py-2.5 text-n-slate-12"
          />
        </label>
        <p v-if="!linkedContact" class="text-xs text-n-slate-11">
          {{ t('CRM.LEAD_FORM.IDENTITY_HINT') }}
        </p>
        <p
          v-if="errorMessage"
          role="alert"
          class="rounded-xl bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
        >
          {{ errorMessage }}
        </p>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            :disabled="saving"
            class="mr-auto rounded-xl border border-n-weak px-3 py-2"
            @click="draft.discard"
          >
            {{ t('CRM.CREATION.DISCARD') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-xl border border-n-weak px-4 py-2.5 font-semibold text-n-slate-12 disabled:opacity-50"
            @click="close"
          >
            {{ t('CRM.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="saving"
            class="rounded-xl bg-n-brand px-5 py-2.5 font-semibold text-white disabled:opacity-50"
          >
            {{ saving ? t('CRM.LEAD_FORM.SAVING') : t('CRM.LEAD_FORM.SAVE') }}
          </button>
        </div>
      </form>
    </div>
  </Teleport>
  <LeadContactCreateDialog
    v-if="showContactForm"
    :company-id="companyId"
    :company-name="form.company_name"
    @created="contactCreated"
    @close="showContactForm = false"
  />
</template>
