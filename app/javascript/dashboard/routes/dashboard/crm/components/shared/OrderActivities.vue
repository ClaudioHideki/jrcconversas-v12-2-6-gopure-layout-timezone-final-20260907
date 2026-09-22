<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Fixed local option keys. */
import { ref, reactive, watch, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { activitiesAPI } from 'dashboard/api/crm';
import AgentsAPI from 'dashboard/api/agents';
const props = defineProps({ orderId: { type: Number, required: true } });
const { t } = useI18n();
const store = useStore();
const rows = ref([]);
const agents = ref([]);
const error = ref('');
const saving = ref(false);
const editing = ref(null);
const isAdmin = computed(
  () => store.getters.getCurrentRole === 'administrator'
);
const form = reactive({
  title: '',
  description: '',
  activity_type: 'follow_up',
  due_at: '',
  user_id: null,
});
const load = async () => {
  try {
    rows.value = (
      await activitiesAPI.list({ sales_order_id: props.orderId })
    ).data;
  } catch {
    error.value = t('CRM.COMMERCIAL.LOAD_ERROR');
  }
};
const edit = row => {
  editing.value = row.id;
  const d = new Date(row.due_at);
  const local = row.due_at
    ? new Date(d.getTime() - d.getTimezoneOffset() * 60000)
        .toISOString()
        .slice(0, 16)
    : '';
  Object.assign(form, {
    title: row.title,
    description: row.description,
    activity_type: row.activity_type,
    due_at: local,
    user_id: row.user?.id,
  });
};
const save = async () => {
  saving.value = true;
  error.value = '';
  try {
    const payload = { activity: { ...form, sales_order_id: props.orderId } };
    if (!isAdmin.value) delete payload.activity.user_id;
    if (editing.value) await activitiesAPI.update(editing.value, payload);
    else await activitiesAPI.create(payload);
    editing.value = null;
    Object.assign(form, { title: '', description: '', due_at: '' });
    await load();
  } catch (e) {
    error.value = []
      .concat(e.response?.data?.errors || t('CRM.COMMERCIAL.SAVE_ERROR'))
      .join(', ');
  } finally {
    saving.value = false;
  }
};
const complete = async row => {
  saving.value = true;
  try {
    await activitiesAPI.complete(row.id);
    await load();
  } catch {
    error.value = t('CRM.COMMERCIAL.SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
watch(
  () => props.orderId,
  async () => {
    editing.value = null;
    await load();
    if (isAdmin.value) {
      try {
        agents.value = (await AgentsAPI.get()).data;
      } catch {
        error.value = t('CRM.COMMERCIAL.LOAD_ERROR');
      }
    }
  },
  { immediate: true }
);
</script>

<template>
  <section class="mt-4 rounded-xl border border-n-weak p-4">
    <h4 class="font-semibold">{{ t('CRM.COMMERCIAL.NEXT_STEPS') }}</h4>
    <p v-if="error" role="alert" class="text-sm text-red-700">{{ error }}</p>
    <article
      v-for="row in rows"
      :key="row.id"
      class="mt-3 border-b border-n-weak pb-3 text-sm"
    >
      <b>{{ row.title }}</b>
      <p>
        {{ [row.due_at_display, row.user?.name].filter(Boolean).join(' · ') }}
      </p>
      <p>{{ row.description }}</p>
      <div
        v-if="!row.completed_at && row.status !== 'cancelled'"
        class="mt-2 flex gap-2"
      >
        <button
          class="rounded border px-2 py-1"
          :disabled="saving"
          @click="edit(row)"
        >
          {{ t('CRM.HOMOLOGATION.EDIT') }}
        </button>
        <button
          class="rounded border px-2 py-1"
          :disabled="saving"
          @click="complete(row)"
        >
          {{ t('CRM.COMMERCIAL.COMPLETE') }}
        </button>
      </div>
      <span v-else>{{ t('CRM.COMMERCIAL.COMPLETED') }}</span>
    </article>
    <form class="mt-4 grid gap-3 text-sm" @submit.prevent="save">
      <label
        >{{ t('CRM.COMMERCIAL.TITLE')
        }}<input
          v-model="form.title"
          required
          class="mt-1 w-full rounded border p-2"
      /></label>
      <label
        >{{ t('CRM.COMMERCIAL.DATE')
        }}<input
          v-model="form.due_at"
          type="datetime-local"
          required
          class="mt-1 w-full rounded border p-2"
      /></label>
      <label
        >{{ t('CRM.COMMERCIAL.TYPE')
        }}<select
          v-model="form.activity_type"
          class="mt-1 w-full rounded border p-2"
        >
          <option
            v-for="kind in [
              'follow_up',
              'call',
              'meeting',
              'task',
              'email',
              'whatsapp',
            ]"
            :key="kind"
            :value="kind"
          >
            {{ t('CRM.COMMERCIAL.ACTIVITY_TYPES.' + kind) }}
          </option>
        </select></label
      >
      <label v-if="isAdmin"
        >{{ t('CRM.COMMERCIAL.OWNER')
        }}<select v-model="form.user_id" class="mt-1 w-full rounded border p-2">
          <option :value="null">{{ t('CRM.COMMERCIAL.ME') }}</option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select></label
      >
      <label
        >{{ t('CRM.COMMERCIAL.DESCRIPTION')
        }}<textarea
          v-model="form.description"
          class="mt-1 w-full rounded border p-2"
        />
      </label>
      <button
        v-if="editing"
        type="button"
        class="rounded-lg border px-3 py-2"
        @click="
          editing = null;
          Object.assign(form, {
            title: '',
            description: '',
            due_at: '',
            user_id: null,
          });
        "
      >
        {{ t('CRM.CANCEL') }}</button
      ><button
        class="rounded-lg bg-n-brand px-3 py-2 font-semibold text-white"
        :disabled="saving"
      >
        {{ t('CRM.HOMOLOGATION.SAVE') }}
      </button>
    </form>
  </section>
</template>
