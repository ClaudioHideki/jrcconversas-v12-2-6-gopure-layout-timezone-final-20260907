<script setup>
import { ref, computed, toRef, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import { COMPONENT_TYPES, MEDIA_FORMATS, findComponentByType } from 'dashboard/helper/templateHelper';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
import TemplatesAPI from 'dashboard/api/whatsappTemplates';

const props = defineProps({ inboxId: { type: Number, default: undefined }, conversationId: { type: Number, default: undefined } });
const emit = defineEmits(['onSelect']);
const { t } = useI18n();
const store = useStore();
const query = ref('');
const category = ref('');
const language = ref('');
const favoritesOnly = ref(false);
const isRefreshing = ref(false);
const loading = ref(false);
const loadError = ref('');
const canManage = ref(false);
const remoteTemplates = ref([]);
let generation = 0;
const official = computed(() => store.getters['inboxes/getInbox'](props.inboxId)?.channel_type === 'Channel::Whatsapp');
const legacyTemplates = useFunctionGetter('inboxes/getFilteredWhatsAppTemplates', toRef(props, 'inboxId'));
const whatsAppTemplateMessages = computed(() => official.value ? remoteTemplates.value : legacyTemplates.value);
const categories = computed(() => [...new Set(whatsAppTemplateMessages.value.map(item => item.category))].filter(Boolean).sort());
const languages = computed(() => [...new Set(whatsAppTemplateMessages.value.map(item => item.language))].filter(Boolean).sort());
const filteredTemplateMessages = computed(() => whatsAppTemplateMessages.value.filter(template =>
  `${template.name} ${getTemplateBody(template)}`.toLowerCase().includes(query.value.toLowerCase()) &&
  (!category.value || template.category === category.value) &&
  (!language.value || template.language === language.value) &&
  (!favoritesOnly.value || template.jrc?.favorite)
).sort((a, b) => Number(!!b.jrc?.favorite) - Number(!!a.jrc?.favorite) || a.name.localeCompare(b.name)));
const getTemplateBody = template => findComponentByType(template, COMPONENT_TYPES.BODY)?.text || '';
const getTemplateHeader = template => findComponentByType(template, COMPONENT_TYPES.HEADER);
const getTemplateFooter = template => findComponentByType(template, COMPONENT_TYPES.FOOTER);
const getTemplateButtons = template => findComponentByType(template, COMPONENT_TYPES.BUTTONS);
const hasMediaContent = template => MEDIA_FORMATS.includes(getTemplateHeader(template)?.format);
const load = async () => {
  if (!official.value || !props.conversationId) return;
  const request = ++generation;
  loading.value = true;
  loadError.value = '';
  try {
    const { data } = await TemplatesAPI.catalog(props.inboxId, { conversation_id: props.conversationId });
    if (request !== generation) return;
    remoteTemplates.value = data.templates;
    canManage.value = data.can_manage;
    if (data.sync_error) loadError.value = data.sync_error;
  } catch (error) {
    if (request === generation) loadError.value = error.response?.data?.error || 'Não foi possível carregar os modelos desta caixa.';
  } finally { if (request === generation) loading.value = false; }
};
watch(() => [props.inboxId, props.conversationId], () => {
  generation += 1;
  remoteTemplates.value = [];
  canManage.value = false;
  load();
}, { immediate: true });
const refreshTemplates = async () => {
  isRefreshing.value = true;
  try {
    if (official.value) {
      await TemplatesAPI.refresh(props.inboxId);
      await load();
    } else { await store.dispatch('inboxes/syncTemplates', props.inboxId); }
    useAlert(t('WHATSAPP_TEMPLATES.PICKER.REFRESH_SUCCESS'));
  } catch (error) {
    useAlert(error.response?.data?.error || t('WHATSAPP_TEMPLATES.PICKER.REFRESH_ERROR'));
  } finally { isRefreshing.value = false; }
};
</script>

<template>
  <div class="w-full">
    <div class="flex gap-2 mb-2.5">
      <div
        class="flex flex-1 gap-1 items-center px-2.5 py-0 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 focus-within:outline-n-brand dark:focus-within:outline-n-brand"
      >
        <fluent-icon icon="search" class="text-n-slate-12" size="16" />
        <input
          v-model="query"
          type="search"
          :placeholder="t('WHATSAPP_TEMPLATES.PICKER.SEARCH_PLACEHOLDER')"
          class="reset-base w-full h-9 bg-transparent text-n-slate-12 !text-sm !outline-0"
        />
      </div>
      <button
        v-if="!official || canManage"
        :disabled="isRefreshing"
        class="flex justify-center items-center w-9 h-9 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak hover:outline-n-slate-6 dark:hover:outline-n-slate-6 hover:bg-n-alpha-2 dark:hover:bg-n-solid-2 disabled:opacity-50 disabled:cursor-not-allowed"
        :title="t('WHATSAPP_TEMPLATES.PICKER.REFRESH_BUTTON')"
        @click="refreshTemplates"
      >
        <Icon
          icon="i-lucide-refresh-ccw"
          class="text-n-slate-12 size-4"
          :class="{ 'animate-spin': isRefreshing }"
        />
      </button>
    </div>
    <div class="flex gap-2 flex-wrap mb-3 items-center">
      <select v-model="category" aria-label="Categoria" class="!mb-0 !w-auto !text-sm">
        <option value="">Todas as categorias</option>
        <option v-for="item in categories" :key="item" :value="item">{{ item }}</option>
      </select>
      <select v-model="language" aria-label="Idioma" class="!mb-0 !w-auto !text-sm">
        <option value="">Todos os idiomas</option>
        <option v-for="item in languages" :key="item" :value="item">{{ item }}</option>
      </select>
      <label v-if="official" class="flex gap-2 items-center text-sm mb-0"><input v-model="favoritesOnly" type="checkbox" class="!mb-0" /> Favoritos da equipe</label>
      <span class="text-xs text-n-teal-11">Somente aprovados</span>
    </div>
    <p v-if="loading" role="status" class="text-sm">Carregando modelos desta caixa...</p>
    <div v-if="loadError" role="alert" class="text-sm p-3 mb-3 rounded-lg bg-n-amber-2 text-n-amber-11">
      {{ loadError }} <button type="button" class="underline" @click="load">Tentar novamente</button>
    </div>
    <div
      class="bg-n-background outline-n-container outline outline-1 rounded-lg max-h-[18.75rem] overflow-y-auto p-2.5"
    >
      <div v-for="(template, i) in filteredTemplateMessages" :key="template.id">
        <button
          class="block p-2.5 w-full text-left rounded-lg cursor-pointer hover:bg-n-alpha-2 dark:hover:bg-n-solid-2"
          @click="emit('onSelect', template)"
        >
          <div>
            <div class="flex justify-between items-center mb-2.5">
              <p class="text-sm">
                {{ template.jrc?.favorite ? "★ " : "" }}{{ template.name }}
              </p>
              <span
                class="inline-block px-2 py-1 text-xs leading-none rounded-lg cursor-default bg-n-slate-3 text-n-slate-12"
              >
                {{ t('WHATSAPP_TEMPLATES.PICKER.LABELS.LANGUAGE') }}:
                {{ template.language }}
              </span>
            </div>
            <!-- Header -->
            <div v-if="getTemplateHeader(template)" class="mb-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.HEADER') || 'HEADER' }}
              </p>
              <div
                v-if="getTemplateHeader(template).format === 'TEXT'"
                class="text-sm label-body"
              >
                {{ getTemplateHeader(template).text }}
              </div>
              <div
                v-else-if="hasMediaContent(template)"
                class="text-sm italic text-n-slate-11"
              >
                {{
                  t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT', {
                    format: getTemplateHeader(template).format,
                  }) ||
                  `${getTemplateHeader(template).format} ${t('WHATSAPP_TEMPLATES.PICKER.MEDIA_CONTENT_FALLBACK')}`
                }}
              </div>
            </div>

            <!-- Body -->
            <div>
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BODY') || 'BODY' }}
              </p>
              <p class="text-sm label-body">{{ getTemplateBody(template) }}</p>
            </div>

            <!-- Footer -->
            <div v-if="getTemplateFooter(template)" class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.FOOTER') || 'FOOTER' }}
              </p>
              <p class="text-sm label-body">
                {{ getTemplateFooter(template).text }}
              </p>
            </div>

            <!-- Buttons -->
            <div v-if="getTemplateButtons(template)" class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.BUTTONS') || 'BUTTONS' }}
              </p>
              <div class="flex flex-wrap gap-1 mt-1">
                <span
                  v-for="button in getTemplateButtons(template).buttons"
                  :key="button.text"
                  class="px-2 py-1 text-xs rounded bg-n-slate-3 text-n-slate-12"
                >
                  {{ button.text }}
                </span>
              </div>
            </div>

            <div class="mt-3">
              <p class="text-xs font-medium text-n-slate-11">
                {{ t('WHATSAPP_TEMPLATES.PICKER.CATEGORY') || 'CATEGORY' }}
              </p>
              <p class="text-sm">{{ template.category }}</p>
            </div>
          </div>
        </button>
        <hr
          v-if="i != filteredTemplateMessages.length - 1"
          :key="`hr-${i}`"
          class="border-b border-solid border-n-weak my-2.5 mx-auto max-w-[95%]"
        />
      </div>
      <div v-if="!loading && !filteredTemplateMessages.length" class="py-8 text-center">
        <div v-if="whatsAppTemplateMessages.length">
          <p>
            {{ t('WHATSAPP_TEMPLATES.PICKER.NO_TEMPLATES_FOUND') }}
            <strong>{{ query }}</strong>
          </p>
        </div>
        <div v-else-if="!whatsAppTemplateMessages.length" class="space-y-4">
          <p class="text-n-slate-11">
            Nenhum modelo aprovado e autorizado para esta caixa/equipe. Peça ao administrador para sincronizar e conferir as permissões.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.label-body {
  font-family: monospace;
}
</style>
