<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Fixed local option keys. */
import { reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { salesOrdersAPI } from 'dashboard/api/crm/commercialCycle';

const props = defineProps({ order: { type: Object, required: true } });
const emit = defineEmits(['saved']);
const { t } = useI18n();
const editing = ref(false);
const busy = ref(false);
const error = ref('');
const form = reactive({ discount: 0, shipping: 0, taxes: 0, surcharge: 0 });
const money = value =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    Number(value || 0) / 100
  );
const start = () => {
  Object.assign(form, {
    discount: props.order.discount_cents / 100,
    shipping: props.order.shipping_cents / 100,
    taxes: props.order.snapshot?.taxes_percent || 0,
    surcharge: (props.order.snapshot?.surcharge_cents || 0) / 100,
  });
  editing.value = true;
  error.value = '';
};
const save = async () => {
  busy.value = true;
  try {
    const { data } = await salesOrdersAPI.update(props.order.id, {
      sales_order: {
        discount_cents: Math.round(form.discount * 100),
        shipping_cents: Math.round(form.shipping * 100),
        snapshot: {
          discount_percent: null,
          taxes_percent: form.taxes,
          surcharge_cents: Math.round(form.surcharge * 100),
        },
      },
    });
    emit('saved', data);
    editing.value = false;
  } catch (failure) {
    error.value =
      failure.response?.data?.message ||
      failure.response?.data?.errors?.join(', ') ||
      t('CRM.COMMERCIAL.SAVE_ERROR');
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <section class="mt-4 rounded-xl border border-n-weak p-4">
    <header class="flex items-center justify-between gap-2">
      <h4 class="font-semibold">{{ t('CRM.COMMERCIAL.FINANCIAL') }}</h4>
      <button
        v-if="!editing"
        class="rounded-lg border px-3 py-2"
        @click="start"
      >
        {{ t('CRM.HOMOLOGATION.EDIT') }}
      </button>
    </header>
    <form
      v-if="editing"
      class="mt-3 grid grid-cols-2 gap-3"
      @submit.prevent="save"
    >
      <label
        v-for="field in ['discount', 'shipping', 'taxes', 'surcharge']"
        :key="field"
        class="text-sm"
      >
        {{ t(`CRM.COMMERCIAL.FINANCIAL_FIELDS.${field}`) }}
        <input
          v-model.number="form[field]"
          type="number"
          min="0"
          step="0.01"
          required
          class="mt-1 w-full rounded-lg border p-2"
        />
      </label>
      <p v-if="error" role="alert" class="col-span-2 text-sm text-red-700">
        {{ error }}
      </p>
      <div class="col-span-2 flex justify-end gap-2">
        <button
          type="button"
          :disabled="busy"
          class="rounded-lg border px-3 py-2"
          @click="editing = false"
        >
          {{ t('CRM.CANCEL') }}
        </button>
        <button
          :disabled="busy"
          class="rounded-lg bg-n-brand px-3 py-2 text-white"
        >
          {{ t('CRM.HOMOLOGATION.SAVE') }}
        </button>
      </div>
    </form>
    <dl v-else class="mt-3 space-y-2 text-sm">
      <div
        v-for="row in [
          ['SUBTOTAL', order.products_cents],
          ['DISCOUNT', -order.discount_cents],
          ['SHIPPING', order.shipping_cents],
          ['TAXES', order.snapshot?.taxes_cents],
          ['SURCHARGE', order.snapshot?.surcharge_cents],
          ['INITIAL', order.total_cents],
        ]"
        :key="row[0]"
        class="flex justify-between gap-3"
      >
        <dt>{{ t(`CRM.COMMERCIAL.${row[0]}`) }}</dt>
        <dd>{{ money(row[1]) }}</dd>
      </div>
    </dl>
  </section>
</template>
