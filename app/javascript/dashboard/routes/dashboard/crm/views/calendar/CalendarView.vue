<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CrmContactActions from '../../components/shared/CrmContactActions.vue';
import { useStore } from 'vuex';
import { activitiesAPI } from 'dashboard/api/crm';
import { formatCrmDateTime } from '../../utils/dateTime';
import CrmPageHeader from '../../components/shared/CrmPageHeader.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const view = ref(['month', 'week', 'day', 'list'].includes(route.query.view) ? route.query.view : 'week');
const selectedTypes = ref(['call', 'meeting', 'whatsapp', 'other']);
const calendars = ref(['mine', 'team']);
const selectedActivityId = ref(null);
const refreshing = ref(false);
const filteredActivities = computed(() => activities.value.filter(activity => {
  const own = activity.user?.id === store.getters.getCurrentUser?.id;
  const type = ['call', 'meeting', 'whatsapp'].includes(activity.activity_type) ? activity.activity_type : 'other';
  return calendars.value.includes(own ? 'mine' : 'team') && selectedTypes.value.includes(type);
}));
const upcoming = computed(() => filteredActivities.value.filter(activity => !activity.completed_at && activity.status !== 'cancelled'));
const selectedActivity = computed(() => filteredActivities.value.find(activity => activity.id === selectedActivityId.value) || upcoming.value[0]);
const refresh = async () => {
  refreshing.value = true;
  try { await store.dispatch('jrcCrm/activities/fetchActivities'); }
  finally { refreshing.value = false; }
};
const activities = computed(() =>
  [...(store.getters['jrcCrm/activities/allActivities'] || [])].sort(
    (left, right) => new Date(left.due_at) - new Date(right.due_at)
  )
);
const loading = computed(() => store.getters['jrcCrm/activities/isLoading']);
const error = computed(() => store.getters['jrcCrm/activities/error']);
const routeDate = route.query.date ? new Date(String(route.query.date)) : null;
const calendarDate = ref(routeDate && !Number.isNaN(routeDate.getTime()) ? routeDate : new Date());

const miniDate = ref(new Date(calendarDate.value));
const dateKey = date => [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-');
watch([calendarDate, view], () => router.replace({ query: { ...route.query, date: dateKey(calendarDate.value), view: view.value } }));

const startOfWeek = computed(() => {
  const source = calendarDate.value;
  const date = new Date(source);
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date;
});

const weekDays = computed(() =>
  Array.from({ length: 7 }, (_, index) => {
    const date = new Date(startOfWeek.value);
    date.setDate(date.getDate() + index);
    const key = [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-');
    return {
      key,
      date,
      weekday: new Intl.DateTimeFormat('pt-BR', { weekday: 'short' }).format(date).replace('.', ''),
      day: String(date.getDate()).padStart(2, '0'),
      activities: filteredActivities.value.filter(activity => {
        const d = new Date(activity.due_at);
        const activityKey = [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
        return activityKey === key;
      }),
    };
  })
);

const monthLabel = computed(() =>
  new Intl.DateTimeFormat('pt-BR', { month: 'long', year: 'numeric' }).format(calendarDate.value)
);

const changeMonth = offset => {
  const next = new Date(miniDate.value);
  next.setDate(1);
  next.setMonth(next.getMonth() + offset);
  miniDate.value = next;
};

const goToday = () => {
  calendarDate.value = new Date();
  miniDate.value = new Date(calendarDate.value);
};

const miniCalendarDays = computed(() => {
  const year = miniDate.value.getFullYear();
  const month = miniDate.value.getMonth();
  const first = new Date(year, month, 1);
  const mondayIndex = (first.getDay() + 6) % 7;
  const start = new Date(year, month, 1 - mondayIndex);
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    return {
      key: dateKey(date),
      day: date.getDate(),
      currentMonth: date.getMonth() === month,
      today: date.toDateString() === new Date().toDateString(),
      selected: date.toDateString() === calendarDate.value.toDateString(),
      date,
    };
  });
});


const selectCalendarDay = day => {
  calendarDate.value = new Date(day.date);
  miniDate.value = new Date(day.date);
};

const miniMonthLabel = computed(() => new Intl.DateTimeFormat('pt-BR', { month: 'long', year: 'numeric' }).format(miniDate.value));
const visibleDays = computed(() => {
  if (view.value === 'week') return weekDays.value;
  const source = calendarDate.value;
  const first = new Date(source.getFullYear(), source.getMonth(), 1);
  const start = view.value === 'day' ? new Date(source) : new Date(source.getFullYear(), source.getMonth(), 1 - (first.getDay() + 6) % 7);
  return Array.from({ length: view.value === 'day' ? 1 : 42 }, (_, index) => {
    const date = new Date(start); date.setDate(date.getDate() + index);
    return { key: dateKey(date), date, day: date.getDate(), weekday: new Intl.DateTimeFormat('pt-BR', { weekday: 'short' }).format(date), activities: filteredActivities.value.filter(activity => dateKey(new Date(activity.due_at)) === dateKey(date)) };
  });
});
const listActivities = computed(() => filteredActivities.value.filter(activity => {
  const date = new Date(activity.due_at);
  return date.getMonth() === calendarDate.value.getMonth() && date.getFullYear() === calendarDate.value.getFullYear();
}));
const periodLabel = computed(() => {
  if (view.value === 'month' || view.value === 'list') return monthLabel.value;
  const days = visibleDays.value;
  return days.length === 1 ? days[0].date.toLocaleDateString('pt-BR') : days[0].date.toLocaleDateString('pt-BR') + ' – ' + days[6].date.toLocaleDateString('pt-BR');
});
const changePeriod = offset => {
  const next = new Date(calendarDate.value);
  if (view.value === 'month' || view.value === 'list') { next.setDate(1); next.setMonth(next.getMonth() + offset); }
  else next.setDate(next.getDate() + offset * (view.value === 'week' ? 7 : 1));
  calendarDate.value = next;
  miniDate.value = new Date(next);
};

const activityIcon = type => ({
  call: 'i-lucide-phone',
  meeting: 'i-lucide-users-round',
  follow_up: 'i-lucide-message-circle-more',
  demonstration: 'i-lucide-monitor-play',
  email: 'i-lucide-mail',
}[type] || 'i-lucide-list-checks');

const activityTone = activity => {
  if (activity.overdue) return 'border-[#fecaca] bg-[#fff3f3] text-[#b42318]';
  if (activity.completed_at) return 'border-[#bbf7d0] bg-[#effdf5] text-[#067647]';
  const tones = {
    call: 'border-[#bfdbfe] bg-[#eff6ff] text-[#175cd3]',
    meeting: 'border-[#ddd6fe] bg-[#f5f3ff] text-[#6941c6]',
    follow_up: 'border-[#bbf7d0] bg-[#effdf5] text-[#067647]',
    demonstration: 'border-[#a5f3fc] bg-[#ecfeff] text-[#0e7490]',
    email: 'border-[#fed7aa] bg-[#fff7ed] text-[#c2410c]',
  };
  return tones[activity.activity_type] || 'border-[#dbe4ef] bg-[#f8fafc] text-[#475467]';
};

const complete = async id => {
  try { await activitiesAPI.complete(id); await refresh(); }
  catch { useAlert(t('CRM.HOMOLOGATION.ACTIVITY_COMPLETE_ERROR')); }
};

onMounted(async () => {
  await store.dispatch('jrcCrm/activities/fetchActivities');
  if (!route.query.date) {
    const next = activities.value.find(item => !item.completed_at && new Date(item.due_at) >= new Date());
    if (next) { calendarDate.value = new Date(next.due_at); miniDate.value = new Date(next.due_at); }
  }
});
</script>

<template>
  <div class="h-full overflow-auto bg-transparent">
    <div class="mx-auto flex min-h-full w-full max-w-[1680px] flex-col gap-5 p-4 sm:p-6">
      <CrmPageHeader
        title="Agenda comercial"
        description="Organize reuniões, ligações, retornos e compromissos da equipe."
        icon="i-lucide-calendar-days"
        tone="iris"
      >
        <template #actions>
          <RouterLink :to="{ name: 'crm_leads', query: { new: '1' } }" class="rounded-xl bg-blue-700 px-4 py-2.5 text-sm font-semibold text-white shadow-md">
            <i class="i-lucide-plus mr-1 size-4" /> Novo lead
          </RouterLink>
          <RouterLink :to="{ name: 'crm_activities', query: { new: '1' } }" class="rounded-xl bg-[#7c3aed] px-4 py-2.5 text-sm font-semibold text-white shadow-md">
            <i class="i-lucide-plus mr-1 size-4" /> Novo compromisso
          </RouterLink>
          <button type="button" :disabled="refreshing" @click="refresh" class="rounded-xl bg-n-brand px-4 py-2.5 text-sm font-semibold text-white shadow-md disabled:opacity-60">
            <i class="i-lucide-refresh-cw mr-1 size-4" /> {{ t('CRM.HOMOLOGATION.REFRESH_CALENDAR') }}
          </button>
        </template>
      </CrmPageHeader>

      <p class="rounded-xl border border-n-weak bg-n-solid-2 p-3 text-xs text-n-slate-11">{{ t('CRM.HOMOLOGATION.CALENDAR_LOCAL') }}</p>
      <div class="grid grid-cols-1 gap-4 min-[768px]:grid-cols-[210px_minmax(0,1fr)]">
        <aside class="rounded-2xl border border-[#e4e9f1] bg-white p-4 shadow-sm">
          <div class="mb-4 flex items-center justify-between">
            <button type="button" class="grid size-8 place-content-center rounded-lg border border-[#e4e9f1] text-[#667085] transition hover:bg-[#f5f7fb]" aria-label="Mês anterior" @click="changeMonth(-1)"><i class="i-lucide-chevron-left size-4" /></button>
            <strong class="text-sm capitalize text-[#1d2939]">{{ miniMonthLabel }}</strong>
            <button type="button" class="grid size-8 place-content-center rounded-lg border border-[#e4e9f1] text-[#667085] transition hover:bg-[#f5f7fb]" aria-label="Próximo mês" @click="changeMonth(1)"><i class="i-lucide-chevron-right size-4" /></button>
          </div>
          <div class="grid grid-cols-7 gap-1 text-center text-[11px] text-n-slate-11">
            <span v-for="day in ['S','T','Q','Q','S','S','D']" :key="day">{{ day }}</span>
            <button v-for="day in miniCalendarDays" :key="day.key" type="button" class="grid aspect-square place-content-center rounded-full text-[11px] transition" :class="[day.today ? 'ring-1 ring-violet-600' : '', day.selected ? 'bg-violet-700 !text-white font-bold hover:bg-violet-800' : day.currentMonth ? 'text-n-slate-12 hover:bg-n-slate-3' : 'text-n-slate-11 hover:bg-n-slate-3']" @click="selectCalendarDay(day)">{{ day.day }}</button>
          </div>
          <div class="mt-6 border-t border-[#eef1f5] pt-4">
            <h3 class="mb-3 text-sm font-semibold text-[#344054]">Calendários</h3>
            <label v-for="item in ['mine','team','call','meeting','whatsapp','other']" :key="item" class="mb-2 flex items-center gap-2 text-xs text-[#475467]">
              <input v-if="['mine','team'].includes(item)" v-model="calendars" :value="item" type="checkbox" class="size-3.5 rounded" /><input v-else v-model="selectedTypes" :value="item" type="checkbox" class="size-3.5 rounded" /> {{ t('CRM.HOMOLOGATION.CALENDARS.' + item) }}
            </label>
          </div>
          <div class="mt-6 border-t border-[#eef1f5] pt-4">
            <div class="mb-2 flex items-center justify-between"><h3 class="text-sm font-semibold text-[#344054]">Próximos</h3><RouterLink :to="{ name: 'crm_activities' }" class="text-[11px] font-semibold text-[#087cf0]">Ver todos</RouterLink></div>
            <div v-for="activity in upcoming.slice(0,3)" :key="activity.id" class="mb-3 flex gap-2 text-xs">
              <span class="grid size-7 shrink-0 place-content-center rounded-lg bg-[#f4f3ff] text-[#7c3aed]"><i class="size-3.5" :class="activityIcon(activity.activity_type)" /></span>
              <div class="min-w-0"><p class="truncate font-semibold text-[#344054]">{{ activity.title }}</p><p class="text-[#98a2b3]">{{ formatCrmDateTime(activity.due_at) }}</p></div>
            </div>
          </div>
        </aside>

        <section class="overflow-hidden rounded-2xl border border-[#e4e9f1] bg-white shadow-sm">
          <div class="flex flex-wrap items-center justify-between gap-3 border-b border-[#e9edf3] px-4 py-3">
            <div class="flex items-center gap-2">
              <button type="button" class="grid size-9 place-content-center rounded-lg border border-[#e4e9f1] text-[#667085] transition hover:bg-[#f5f7fb]" :aria-label="t('CRM.HOMOLOGATION.PREVIOUS_PERIOD')" @click="changePeriod(-1)"><i class="i-lucide-chevron-left size-4" /></button>
              <button type="button" class="grid size-9 place-content-center rounded-lg border border-[#e4e9f1] text-[#667085] transition hover:bg-[#f5f7fb]" :aria-label="t('CRM.HOMOLOGATION.NEXT_PERIOD')" @click="changePeriod(1)"><i class="i-lucide-chevron-right size-4" /></button>
              <button type="button" class="rounded-lg border border-[#e4e9f1] px-3 py-2 text-sm text-[#475467] transition hover:bg-[#f5f7fb]" @click="goToday">Hoje</button>
              <strong class="ml-2 capitalize text-[#1d2939]">{{ periodLabel }}</strong>
            </div>
            <div class="flex rounded-lg border border-[#e4e9f1] bg-[#f8fafc] p-1 text-xs">
              <button v-for="mode in ['month','week','day','list']" :key="mode" type="button" :aria-pressed="view === mode" class="rounded-md px-3 py-1.5" :class="view === mode ? 'bg-violet-700 text-white font-semibold' : 'text-n-slate-11 hover:bg-n-slate-3'" @click="view = mode">{{ t('CRM.HOMOLOGATION.VIEWS.' + mode) }}</button>
            </div>
          </div>

          <div v-if="loading" class="grid min-h-[560px] place-content-center text-sm text-[#667085]">Carregando agenda…</div>
          <div v-else-if="error" class="grid min-h-[560px] place-content-center text-sm text-[#b42318]">{{ error }}</div>
          <div v-else-if="view === 'list'" class="divide-y divide-n-weak p-4">
            <button v-for="activity in listActivities" :key="activity.id" class="flex w-full flex-wrap items-center justify-between gap-3 py-4 text-left hover:bg-n-slate-3" @click="selectedActivityId = activity.id"><strong>{{ activity.title }}</strong><span class="text-sm">{{ formatCrmDateTime(activity.due_at) }}</span></button>
            <p v-if="!listActivities.length" class="py-8 text-center text-n-slate-11">{{ t('CRM.HOMOLOGATION.EMPTY_PERIOD') }}</p>
          </div>
          <div v-else class="overflow-x-auto">
          <div class="grid divide-x divide-n-weak" :class="view === 'day' ? 'grid-cols-1 min-h-[300px]' : 'min-w-[700px] grid-cols-7'">
            <div v-for="day in visibleDays" :key="day.key" class="min-w-0 border-b border-n-weak bg-n-solid-2">
              <header class="border-b border-[#edf0f4] px-2 py-3 text-center">
                <p class="text-[11px] font-semibold uppercase text-[#98a2b3]">{{ day.weekday }}</p>
                <p class="mt-1 text-sm font-bold text-[#344054]">{{ day.day }}</p>
              </header>
              <div class="space-y-2 p-2" :class="view === 'month' ? 'min-h-[110px]' : 'min-h-[300px]'">
                <article v-for="activity in day.activities" :key="activity.id" class="rounded-xl border p-2.5 text-xs shadow-sm" :class="activityTone(activity)">
                  <div class="mb-1 flex items-center gap-1.5 font-bold"><i class="size-3.5" :class="activityIcon(activity.activity_type)" />{{ new Date(activity.due_at).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'}) }}</div>
                  <button class="w-full break-words text-left font-semibold leading-4 underline-offset-2 hover:underline" @click="selectedActivityId = activity.id">{{ activity.title }}</button>
                  <button v-if="!activity.completed_at" type="button" class="mt-2 rounded-md bg-white/70 px-2 py-1 text-[10px] font-semibold" @click="complete(activity.id)">Concluir</button>
                </article>
              </div>
            </div>
          </div>
          </div>
        </section>

        <aside class="rounded-2xl border border-n-weak bg-n-solid-2 p-4 shadow-sm min-[768px]:col-span-2">
          <template v-if="selectedActivity">
            <div class="mb-4 flex items-start justify-between"><div><p class="text-xs font-semibold text-[#667085]">Próxima atividade</p><h3 class="mt-1 text-lg font-bold text-[#1d2939]">{{ selectedActivity.title }}</h3></div></div>
            <dl class="space-y-3 text-xs">
              <div class="flex justify-between gap-3"><dt class="text-[#98a2b3]">Data</dt><dd class="font-semibold text-[#344054]">{{ formatCrmDateTime(selectedActivity.due_at) }}</dd></div>
              <div class="flex justify-between gap-3"><dt class="text-[#98a2b3]">Tipo</dt><dd class="font-semibold text-[#344054]">{{ selectedActivity.activity_type }}</dd></div>
              <div class="flex justify-between gap-3"><dt class="text-[#98a2b3]">Status</dt><dd class="font-semibold text-[#344054]">{{ selectedActivity.completed_at ? 'Concluída' : 'Agendada' }}</dd></div>
            </dl>
            <div class="mt-5 grid gap-2">
              <CrmContactActions :contact="selectedActivity.contact || {}" />
              <RouterLink :to="{ name: 'crm_activities', query: { activityId: selectedActivity.id } }" class="rounded-xl bg-[#7c3aed] px-3 py-2.5 text-center text-sm font-semibold text-white"><i class="i-lucide-calendar mr-1 size-4" /> Reagendar</RouterLink>
              <button v-if="!selectedActivity.completed_at" class="rounded-xl bg-teal-700 px-3 py-2.5 text-sm font-semibold text-white" @click="complete(selectedActivity.id)">Concluir</button>
            </div>
          </template>
          <div v-else class="grid h-full place-content-center text-center text-sm text-[#98a2b3]">Nenhum compromisso agendado.</div>
        </aside>
      </div>
    </div>
  </div>
</template>
