<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
const props = defineProps({
  window: { type: Object, default: () => ({}) },
  timezone: { type: String, default: 'America/Sao_Paulo' },
  refreshing: { type: Boolean, default: false },
  refreshError: { type: Boolean, default: false },
});
defineEmits(['chooseTemplate', 'refresh']);
const isOpen = computed(() => props.window.can_send_free_message === true);
const remaining = computed(() => {
  const minutes = Math.ceil((props.window.remaining_seconds || 0) / 60);
  return minutes >= 60 ? `${Math.floor(minutes / 60)}h ${minutes % 60}min` : `${minutes}min`;
});
const nearExpiry = computed(() => isOpen.value && props.window.remaining_seconds <= 3600);
const lastMessage = computed(() => {
  if (!props.window.last_customer_message_at) return 'Nenhuma mensagem recebida confirmada';
  const value = new Date(props.window.last_customer_message_at);
  if (!Number.isFinite(value.getTime())) return 'Horário não confirmado';
  try {
    return new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: props.timezone }).format(value);
  } catch { return value.toLocaleString('pt-BR'); }
});
</script>
<template>
  <section
    class="mx-2 mb-2 rounded-lg border p-3 text-sm"
    :class="isOpen ? (nearExpiry ? 'border-n-amber-8 bg-n-amber-2' : 'border-n-teal-7 bg-n-teal-2') : 'border-n-weak bg-n-alpha-black2'"
    aria-live="polite" aria-atomic="true"
  >
    <div class="flex items-start justify-between gap-3 flex-wrap">
      <div class="min-w-0 flex-1">
        <p class="font-semibold mb-1 text-n-slate-12">
          {{ isOpen ? (nearExpiry ? 'Janela WhatsApp perto de encerrar' : 'Janela WhatsApp aberta') : 'Janela de atendimento encerrada' }}
          <span v-if="isOpen" class="font-normal"> · {{ remaining }} restantes</span>
        </p>
        <p v-if="!isOpen" class="mb-1 text-n-slate-11">
          {{ window.awaiting_customer_reply ? 'Modelo enviado. Aguardando o cliente responder para liberar a mensagem comum.' : 'Para continuar pelo WhatsApp Oficial, envie um modelo aprovado. A mensagem comum será liberada quando o cliente responder.' }}
        </p>
        <p class="text-xs mb-0 text-n-slate-11">Última mensagem do cliente: {{ lastMessage }}</p>
        <p v-if="refreshError" class="text-xs mt-1 mb-0 text-n-amber-11">Não foi possível atualizar o estado. O envio continua validado pelo servidor.</p>
      </div>
      <div class="flex gap-2 items-center">
        <Button v-if="!isOpen" label="Escolher modelo" icon="i-lucide-file-text" @click="$emit('chooseTemplate')" />
        <Button v-if="refreshError || window.window_status === 'UNKNOWN'" label="Atualizar" color="slate" variant="ghost" :disabled="refreshing" @click="$emit('refresh')" />
      </div>
    </div>
  </section>
</template>
