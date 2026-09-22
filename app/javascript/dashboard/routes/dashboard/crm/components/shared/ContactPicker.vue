<script setup>
import { ref, watch, onBeforeUnmount } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import ContactsAPI from 'dashboard/api/contacts';

const props = defineProps({
  modelValue: { type: [Number, String], default: null },
});
const emit = defineEmits(['update:modelValue', 'select']);
const { t } = useI18n();
const route = useRoute();
const query = ref('');
const rows = ref([]);
const selected = ref(null);
const page = ref(1);
const total = ref(0);
const busy = ref(false);
const error = ref('');
let sequence = 0;
let timer;
const load = async (target = 1) => {
  sequence += 1;
  const request = sequence;
  busy.value = true;
  error.value = '';
  try {
    const { data } = query.value.trim()
      ? await ContactsAPI.search(encodeURIComponent(query.value.trim()), target)
      : await ContactsAPI.get(target);
    if (request !== sequence) return;
    rows.value = data.payload;
    total.value = Number(data.meta.count);
    page.value = target;
  } catch {
    if (request === sequence) error.value = t('CRM.COMMERCIAL.LOAD_ERROR');
  } finally {
    if (request === sequence) busy.value = false;
  }
};
const contactLabel = contact =>
  [contact.name || contact.email, contact.phone_number, `#${contact.id}`]
    .filter(Boolean)
    .join(' · ');
const choose = contact => {
  selected.value = contact;
  emit('update:modelValue', contact.id);
  emit('select', contact);
};
watch(query, () => {
  clearTimeout(timer);
  timer = setTimeout(() => load(1), 250);
});
watch(
  () => [props.modelValue, route.params.accountId],
  async ([id]) => {
    selected.value = null;
    if (id) {
      const accountId = route.params.accountId;
      try {
        const { data } = await ContactsAPI.show(id);
        if (
          String(props.modelValue) === String(id) &&
          route.params.accountId === accountId
        ) {
          selected.value = data.payload;
          emit('select', data.payload);
        }
      } catch {
        error.value = t('CRM.COMMERCIAL.LOAD_ERROR');
      }
    }
  },
  { immediate: true }
);
watch(
  () => route.params.accountId,
  () => {
    query.value = '';
    load(1);
  },
  { immediate: true }
);
onBeforeUnmount(() => {
  clearTimeout(timer);
  sequence += 1;
});
</script>

<template>
  <div class="min-w-0 rounded-xl border border-n-weak bg-n-solid-2 p-3">
    <p v-if="selected" class="mb-2 break-words text-sm font-semibold">
      {{ contactLabel(selected) }}
    </p>
    <input
      v-model="query"
      type="search"
      :aria-label="t('CRM.COMMERCIAL.SEARCH_CONTACT')"
      :placeholder="t('CRM.COMMERCIAL.SEARCH_CONTACT')"
      class="w-full rounded-lg border border-n-weak p-2 text-sm"
    />
    <p v-if="error" role="alert" class="text-sm text-red-700">{{ error }}</p>
    <div class="mt-2 max-h-48 overflow-y-auto" :aria-busy="busy">
      <button
        v-for="contact in rows"
        :key="contact.id"
        type="button"
        class="block w-full rounded-lg p-2 text-left text-sm hover:bg-n-alpha-2"
        :class="
          Number(modelValue) === contact.id ? 'bg-n-alpha-2 font-semibold' : ''
        "
        @click="choose(contact)"
      >
        <span class="block">{{ contactLabel(contact) }}</span>
        <small
          >{{ contact.phone_number }} {{ contact.email }}
          {{ contact.additional_attributes?.company_name }}</small
        >
      </button>
    </div>
    <div class="mt-2 flex items-center justify-between gap-2 text-xs">
      <button
        type="button"
        class="rounded border px-2 py-1"
        :disabled="busy || page <= 1"
        @click="load(page - 1)"
      >
        {{ t('CRM.COMMERCIAL.PREVIOUS') }}
      </button>
      <span>
        {{ [page, total].join(' · ') }} {{ t('CRM.COMMERCIAL.CONTACTS') }}
      </span>
      <button
        type="button"
        class="rounded border px-2 py-1"
        :disabled="busy || page * 15 >= total"
        @click="load(page + 1)"
      >
        {{ t('CRM.COMMERCIAL.NEXT') }}
      </button>
    </div>
  </div>
</template>
