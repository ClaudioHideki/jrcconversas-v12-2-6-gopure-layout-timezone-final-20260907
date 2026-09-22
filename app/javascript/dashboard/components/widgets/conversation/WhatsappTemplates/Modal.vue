<script>
import TemplatesPicker from './TemplatesPicker.vue';
import WhatsAppTemplateReply from './WhatsAppTemplateReply.vue';
export default {
  components: {
    TemplatesPicker,
    WhatsAppTemplateReply,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    conversationId: { type: Number, default: undefined },
    sending: { type: Boolean, default: false },
    inboxId: {
      type: Number,
      default: undefined,
    },
  },
  emits: ['onSend', 'cancel', 'update:show'],
  data() {
    return {
      selectedWaTemplate: null,
    };
  },
  computed: {
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
    modalHeaderContent() {
      return this.selectedWaTemplate
        ? this.$t('WHATSAPP_TEMPLATES.MODAL.TEMPLATE_SELECTED_SUBTITLE', {
            templateName: this.selectedWaTemplate.name,
          })
        : this.$t('WHATSAPP_TEMPLATES.MODAL.SUBTITLE');
    },
  },
  watch: {
    show(value) { if (!value) this.selectedWaTemplate = null; },
    conversationId() { this.selectedWaTemplate = null; },
    inboxId() { this.selectedWaTemplate = null; },
  },
  methods: {
    pickTemplate(template) {
      this.selectedWaTemplate = template;
    },
    onResetTemplate() {
      this.selectedWaTemplate = null;
    },
    onSendMessage(message) {
      if (!this.sending) this.$emit('onSend', message);
    },
    onClose() {
      this.$emit('cancel');
    },
  },
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="modal-big">
    <woot-modal-header
      :header-title="$t('WHATSAPP_TEMPLATES.MODAL.TITLE')"
      :header-content="modalHeaderContent"
    />
    <div class="row modal-content">
      <TemplatesPicker
        v-if="show && !selectedWaTemplate"
        :inbox-id="inboxId"
        :conversation-id="conversationId"
        @on-select="pickTemplate"
      />
      <WhatsAppTemplateReply
        v-else-if="selectedWaTemplate"
        :template="selectedWaTemplate"
        :sending="sending"
        @reset-template="onResetTemplate"
        @send-message="onSendMessage"
      />
    </div>
  </woot-modal>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>
