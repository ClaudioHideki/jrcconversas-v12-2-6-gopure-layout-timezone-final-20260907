<script setup>
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineProps({
  sending: { type: Boolean, default: false },
  template: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['sendMessage', 'resetTemplate']);

const handleSendMessage = payload => {
  emit('sendMessage', payload);
};

const handleResetTemplate = () => {
  emit('resetTemplate');
};
</script>

<template>
  <div class="w-full">
    <WhatsAppTemplateParser
      :template="template"
      :initial-values="template.jrc?.defaults || {}"
      :sending="sending"
      @send-message="handleSendMessage"
      @reset-template="handleResetTemplate"
    >
      <template #actions="{ sendMessage, resetTemplate, disabled }">
        <footer class="flex gap-2 justify-end">
          <NextButton
            faded
            slate
            type="reset"
            :disabled="sending"
            :label="$t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL')"
            @click="resetTemplate"
          />
          <NextButton
            type="button"
            :label="sending ? 'Enviando...' : $t('WHATSAPP_TEMPLATES.PARSER.SEND_MESSAGE_LABEL')"
            :disabled="disabled || sending"
            @click="sendMessage"
          />
        </footer>
      </template>
    </WhatsAppTemplateParser>
  </div>
</template>
