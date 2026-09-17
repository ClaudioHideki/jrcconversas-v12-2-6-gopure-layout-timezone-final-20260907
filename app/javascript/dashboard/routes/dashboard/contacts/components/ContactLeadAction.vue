<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { leadsAPI } from 'dashboard/api/crm';
import LeadCreateModal from '../../crm/views/leads/LeadCreateModal.vue';

const props = defineProps({ contact: { type: Object, required: true } });
const emit = defineEmits(['created']);
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const linked = ref(false);
const leadId = ref(null);
const loading = ref(true);
const failed = ref(false);
const showForm = ref(false);
const retry = ref(0);
const buttonLabel = computed(() => {
  if (loading.value) return t('CRM.CONTACT_LEAD.LOADING');
  if (!linked.value) return t('CRM.CONTACT_LEAD.CREATE');
  return leadId.value
    ? t('CRM.CONTACT_LEAD.VIEW')
    : t('CRM.CONTACT_LEAD.RESTRICTED');
});

watch(
  [() => props.contact.id, retry],
  async ([contactId], _, onCleanup) => {
    let canceled = false;
    onCleanup(() => {
      canceled = true;
    });
    loading.value = true;
    failed.value = false;
    showForm.value = false;
    try {
      const { data } = await leadsAPI.forContact(contactId);
      if (canceled) return;
      linked.value = data.linked;
      leadId.value = data.lead_id;
    } catch {
      if (!canceled) failed.value = true;
    } finally {
      if (!canceled) loading.value = false;
    }
  },
  { immediate: true }
);

const open = () => {
  if (loading.value || failed.value) return;
  if (!linked.value) {
    showForm.value = true;
    return;
  }
  if (leadId.value)
    router.push({
      name: 'crm_leads',
      params: { accountId: route.params.accountId },
      query: { leadId: leadId.value },
    });
};
const created = lead => {
  showForm.value = false;
  linked.value = true;
  leadId.value = lead.id;
  emit('created', lead);
};
</script>

<template>
  <div class="col-span-4">
    <button
      v-if="failed"
      type="button"
      class="w-full rounded-lg border border-n-weak p-2 text-xs text-n-slate-11"
      @click="retry++"
    >
      {{ t('CRM.CONTACT_LEAD.RETRY') }}
    </button>
    <button
      v-else
      type="button"
      :disabled="loading || (linked && !leadId)"
      class="w-full rounded-lg bg-n-brand p-2 text-xs font-semibold text-white disabled:opacity-50"
      @click="open"
    >
      {{ buttonLabel }}
    </button>
    <LeadCreateModal
      v-if="showForm"
      :contact="contact"
      @close="showForm = false"
      @created="created"
    />
  </div>
</template>
