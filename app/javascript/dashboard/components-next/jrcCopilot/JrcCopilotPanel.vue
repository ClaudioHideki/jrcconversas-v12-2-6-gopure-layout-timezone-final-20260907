<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import jrcCopilotAPI from 'dashboard/api/jrcCopilot';
import { useJrcCopilot } from './useJrcCopilot';

const props = defineProps({
  embedded: {
    type: Boolean,
    default: false,
  },
});

const route = useRoute();
const router = useRouter();
const currentUser = useMapGetter('getCurrentUser');
const { isOpen, close, pendingPrompt, consumePrompt } = useJrcCopilot();

const input = ref('');
const sending = ref(false);
const messages = ref([]);
const context = ref({
  title: 'JRC Conversas',
  summary: 'Guia operacional para atendimento e CRM.',
  quick_prompts: [],
  actions: [],
  ai_configured: false,
  can_manage_ai: false,
});
const mode = ref('guide');
const scroller = ref(null);

const isVisible = computed(() => props.embedded || isOpen.value);
const userName = computed(
  () => currentUser.value?.name || currentUser.value?.email || 'Usuário'
);
const aiConfigured = computed(() => Boolean(context.value.ai_configured));
const assistantLabel = computed(() => {
  if (!aiConfigured.value) return 'IA não configurada';
  return mode.value === 'ai' ? 'IA conectada' : 'IA disponível';
});

const fallbackContext = () => ({
  title: 'Copiloto JRC',
  summary:
    'Descreva a tarefa e eu indicarei o módulo, a sequência e os cuidados necessários.',
  quick_prompts: [
    'O que devo fazer agora?',
    'Como registrar a próxima ação?',
    'Onde encontro esta função?',
  ],
  actions: [],
  ai_configured: false,
  can_manage_ai: false,
});

const greeting = data => {
  if (!data.ai_configured) {
    return {
      role: 'assistant',
      content:
        'A Inteligência Artificial ainda não foi configurada pelo administrador desta conta. Cockpit, Conversas, CRM, Agenda, Ligações e WhatsApp Calling continuam funcionando normalmente.',
      actions: data.can_manage_ai
        ? [
            {
              label: 'Configurar Inteligência Artificial',
              route_name: 'jrc_ai_providers',
              icon: 'i-lucide-key-round',
              tone: 'violet',
            },
          ]
        : [],
    };
  }

  return {
    role: 'assistant',
    content: `Olá, ${userName.value}. Estou acompanhando ${data.title}. ${data.summary}`,
    actions: data.actions || [],
  };
};

const scrollToEnd = async () => {
  await nextTick();
  if (scroller.value) {
    scroller.value.scrollTop = scroller.value.scrollHeight;
  }
};

const loadContext = async () => {
  try {
    const { data } = await jrcCopilotAPI.context(route.name);
    context.value = data;
  } catch {
    context.value = fallbackContext();
  }

  if (!messages.value.length || props.embedded) {
    messages.value = [greeting(context.value)];
  } else {
    messages.value.push({
      role: 'assistant',
      content: `Agora estou acompanhando ${context.value.title}. ${context.value.summary}`,
      actions: context.value.actions || [],
      contextual: true,
    });
  }
  scrollToEnd();
};

const sanitizedHistory = computed(() =>
  messages.value
    .filter(message => ['user', 'assistant'].includes(message.role))
    .slice(-8)
    .map(message => ({ role: message.role, content: message.content }))
);

const ask = async prompt => {
  const content = String(prompt ?? input.value).trim();
  if (!content || sending.value || !aiConfigured.value) return;

  const history = sanitizedHistory.value;
  messages.value.push({ role: 'user', content });
  input.value = '';
  sending.value = true;
  scrollToEnd();

  try {
    const { data } = await jrcCopilotAPI.ask({
      message: content,
      route_name: route.name,
      route_path: route.fullPath,
      context: {
        title: context.value.title,
      },
      history,
    });

    mode.value = data.mode || 'guide';
    messages.value.push({
      role: 'assistant',
      content: data.message,
      actions: data.actions || [],
      aiAvailable: data.ai_available,
    });
    if (Array.isArray(data.quick_prompts)) {
      context.value.quick_prompts = data.quick_prompts;
    }
  } catch {
    mode.value = 'guide';
    messages.value.push({
      role: 'assistant',
      content:
        'Não consegui consultar o serviço agora. Continue pela ação indicada na tela ou tente novamente em instantes.',
      actions: context.value.actions || [],
    });
  } finally {
    sending.value = false;
    scrollToEnd();
  }
};

const runPendingPrompt = async () => {
  if (!isVisible.value || sending.value) return;
  const prompt = consumePrompt();
  if (prompt) await ask(prompt);
};

const navigate = async action => {
  if (!action?.route_name) return;
  await router.push({
    name: action.route_name,
    params: { accountId: route.params.accountId },
  });
  if (!props.embedded) close();
};

const resetConversation = () => {
  messages.value = [greeting(context.value)];
  mode.value = 'guide';
  scrollToEnd();
};

watch(
  () => route.name,
  () => loadContext()
);
watch(isVisible, async visible => {
  if (!visible) return;
  await scrollToEnd();
  await runPendingPrompt();
});
watch(pendingPrompt, async value => {
  if (value && isVisible.value) await runPendingPrompt();
});

onMounted(async () => {
  await loadContext();
  await runPendingPrompt();
});
</script>

<template>
  <aside
    v-if="isVisible"
    class="overflow-hidden border border-cyan-200/70 bg-n-solid-2 shadow-2xl"
    :class="
      embedded
        ? 'flex h-full min-h-[620px] w-full flex-col rounded-3xl'
        : 'fixed bottom-4 top-4 ltr:right-4 rtl:left-4 z-[70] flex w-[min(430px,calc(100vw-2rem))] flex-col rounded-3xl'
    "
  >
    <header
      class="relative overflow-hidden bg-gradient-to-br from-[#073b64] via-[#075a87] to-[#07a6c5] px-5 py-4 text-white"
    >
      <div
        class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_80%_20%,rgba(255,255,255,0.24),transparent_38%)]"
      />
      <div class="relative flex items-center gap-3">
        <span
          class="flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-white shadow-lg ring-2 ring-cyan-200/70"
        >
          <img
            :src="'/brand-assets/jrc-copilot-avatar.png'"
            alt="Mascote do Copiloto JRC"
            class="size-full object-cover"
          />
        </span>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <h2 class="truncate text-lg font-bold">Copiloto JRC</h2>
            <span
              class="rounded-full bg-white/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-cyan-50"
            >
              {{ assistantLabel }}
            </span>
          </div>
          <p class="truncate text-xs text-cyan-50/90">
            {{ context.title }} · orientação contextual
          </p>
        </div>
        <button
          type="button"
          class="flex size-9 items-center justify-center rounded-xl bg-white/10 text-white transition hover:bg-white/20"
          title="Reiniciar conversa"
          @click="resetConversation"
        >
          <span class="i-lucide-rotate-ccw size-4" />
        </button>
        <button
          v-if="!embedded"
          type="button"
          class="flex size-9 items-center justify-center rounded-xl bg-white/10 text-white transition hover:bg-white/20"
          aria-label="Fechar Copiloto JRC"
          @click="close"
        >
          <span class="i-lucide-x size-5" />
        </button>
      </div>
    </header>

    <div
      class="border-b border-n-weak bg-gradient-to-r from-cyan-50 to-blue-50 px-4 py-3 dark:from-cyan-950/20 dark:to-blue-950/20"
    >
      <div class="flex items-start gap-2 text-xs text-n-slate-11">
        <span class="i-lucide-compass mt-0.5 size-4 shrink-0 text-cyan-600" />
        <p>{{ context.summary }}</p>
      </div>
    </div>

    <div ref="scroller" class="flex-1 space-y-4 overflow-y-auto bg-n-surface-1 p-4">
      <div
        v-for="(message, index) in messages"
        :key="`${message.role}-${index}`"
        class="flex gap-2"
        :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
      >
        <img
          v-if="message.role === 'assistant'"
          :src="'/brand-assets/jrc-copilot-avatar.png'"
          alt=""
          class="mt-1 size-8 shrink-0 rounded-xl border border-cyan-200 bg-white object-cover"
        />
        <div class="max-w-[84%] space-y-2">
          <div
            class="whitespace-pre-line rounded-2xl px-4 py-3 text-sm leading-relaxed shadow-sm"
            :class="
              message.role === 'user'
                ? 'rounded-br-md bg-n-blue-10 text-white'
                : 'rounded-bl-md border border-n-weak bg-n-solid-2 text-n-slate-12'
            "
          >
            {{ message.content }}
          </div>
          <div
            v-if="message.actions?.length"
            class="flex flex-wrap gap-2"
          >
            <button
              v-for="action in message.actions"
              :key="`${action.label}-${action.route_name}`"
              type="button"
              class="inline-flex items-center gap-1.5 rounded-xl border border-cyan-200 bg-white px-3 py-2 text-xs font-semibold text-[#075a87] shadow-sm transition hover:-translate-y-0.5 hover:border-cyan-400 dark:bg-n-solid-2"
              @click="navigate(action)"
            >
              <span :class="[action.icon || 'i-lucide-arrow-up-right', 'size-4']" />
              {{ action.label }}
            </button>
          </div>
        </div>
      </div>

      <div v-if="sending" class="flex items-center gap-2 text-sm text-n-slate-10">
        <img
          :src="'/brand-assets/jrc-copilot-avatar.png'"
          alt=""
          class="size-8 rounded-xl border border-cyan-200 bg-white object-cover"
        />
        <span class="inline-flex items-center gap-2 rounded-2xl border border-n-weak bg-n-solid-2 px-4 py-3">
          <span class="i-lucide-loader-circle size-4 animate-spin text-cyan-600" />
          Analisando a próxima ação…
        </span>
      </div>
    </div>

    <div class="border-t border-n-weak bg-n-solid-2 p-4">
      <div v-if="aiConfigured && context.quick_prompts?.length" class="mb-3 flex gap-2 overflow-x-auto pb-1">
        <button
          v-for="prompt in context.quick_prompts"
          :key="prompt"
          type="button"
          class="shrink-0 rounded-full border border-n-weak bg-n-alpha-2 px-3 py-1.5 text-xs font-medium text-n-slate-11 transition hover:border-cyan-400 hover:text-cyan-700"
          @click="ask(prompt)"
        >
          {{ prompt }}
        </button>
      </div>
      <form
        class="flex items-end gap-2 rounded-2xl border border-n-weak bg-n-background p-2 focus-within:border-cyan-500"
        @submit.prevent="ask()"
      >
        <textarea
          v-model="input"
          rows="1"
          maxlength="4000"
          :disabled="!aiConfigured"
          :placeholder="
            aiConfigured
              ? 'Descreva o que precisa fazer…'
              : 'IA não configurada pelo administrador'
          "
          class="max-h-28 min-h-10 flex-1 resize-none bg-transparent px-2 py-2 text-sm text-n-slate-12 outline-none"
          @keydown.enter.exact.prevent="ask()"
        />
        <button
          type="submit"
          :disabled="sending || !input.trim() || !aiConfigured"
          class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-cyan-500 to-blue-600 text-white shadow-md transition hover:brightness-105 disabled:cursor-not-allowed disabled:opacity-40"
          aria-label="Enviar para o Copiloto JRC"
        >
          <span class="i-lucide-send size-4" />
        </button>
      </form>
      <p class="mt-2 text-center text-[10px] text-n-slate-8">
        {{
          aiConfigured
            ? 'O Copiloto usa somente a credencial configurada por esta conta.'
            : 'A IA é opcional e os demais recursos continuam disponíveis.'
        }}
      </p>
    </div>
  </aside>
</template>
