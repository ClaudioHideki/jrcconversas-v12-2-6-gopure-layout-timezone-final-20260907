<script setup>
import { computed, ref, watch } from 'vue';
import TemplatesAPI from 'dashboard/api/whatsappTemplates';
import Button from 'dashboard/components-next/button/Button.vue';
import { component } from 'dashboard/helper/whatsappTemplateFlow.mjs';
const props = defineProps({ inbox: { type: Object, required: true } });
const catalog = ref({ templates: [], teams: [] });
const loading = ref(false);
const syncing = ref(false);
const saving = ref(false);
const error = ref('');
const success = ref('');
const query = ref('');
const status = ref('');
const category = ref('');
const language = ref('');
const activeTab = ref('templates');
const selected = ref(null);
const rule = ref({ enabled: true, favorite: false, team_ids: [], bindings: {} });
const entries = ref([]);
const page = ref(1);
let generation = 0;
const sourceLabels = {
  'contact.name': 'Nome do contato', 'contact.phone_number': 'Telefone do contato',
  'contact.email': 'E-mail do contato', 'conversation.display_id': 'Protocolo da conversa',
  'agent.name': 'Nome do agente', 'account.name': 'Nome da empresa', 'team.name': 'Nome da equipe',
};
const unique = key => [...new Set(catalog.value.templates.map(template => template[key]))].filter(Boolean).sort();
const categories = computed(() => unique('category'));
const languages = computed(() => unique('language'));
const statuses = computed(() => unique('status'));
const filtered = computed(() => catalog.value.templates.filter(template =>
  template.name.toLowerCase().includes(query.value.toLowerCase()) &&
  (!status.value || template.status === status.value) &&
  (!category.value || template.category === category.value) &&
  (!language.value || template.language === language.value)
));
const dateLabel = value => {
  if (!value) return 'Ainda não sincronizado';
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '—';
  try { return new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: props.inbox.timezone || 'America/Sao_Paulo' }).format(date); }
  catch { return date.toLocaleString('pt-BR'); }
};
const choose = template => {
  selected.value = template;
  rule.value = {
    enabled: template.jrc.enabled, favorite: template.jrc.favorite,
    team_ids: [...template.jrc.team_ids], bindings: { ...template.jrc.bindings },
  };
  success.value = '';
};
const load = async () => {
  const request = ++generation;
  loading.value = true;
  error.value = '';
  try {
    const { data } = await TemplatesAPI.catalog(props.inbox.id, { management: true });
    if (request !== generation) return;
    catalog.value = data;
    if (selected.value) {
      const updated = data.templates.find(item => item.jrc.key === selected.value.jrc.key);
      if (updated) choose(updated); else selected.value = null;
    }
  } catch (e) { if (request === generation) error.value = e.response?.data?.error || 'Não foi possível carregar os modelos.'; }
  finally { if (request === generation) loading.value = false; }
};
const sync = async () => {
  syncing.value = true;
  error.value = '';
  success.value = '';
  try {
    await TemplatesAPI.refresh(props.inbox.id);
    await load();
    success.value = 'Sincronização concluída com o provedor.';
  } catch (e) { error.value = e.response?.data?.error || 'Não foi possível sincronizar os modelos.'; }
  finally { syncing.value = false; }
};
const save = async () => {
  if (!selected.value || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    await TemplatesAPI.saveRule(props.inbox.id, selected.value.jrc.key, rule.value);
    await load();
    success.value = 'Permissões e preenchimentos salvos.';
  } catch (e) { error.value = e.response?.data?.error || 'Não foi possível salvar.'; }
  finally { saving.value = false; }
};
const loadLogs = async () => {
  loading.value = true;
  error.value = '';
  const id = props.inbox.id;
  const requestedPage = page.value;
  try {
    const { data } = await TemplatesAPI.logs(id, requestedPage);
    if (id === props.inbox.id && requestedPage === page.value) entries.value = data.entries;
  } catch (e) { error.value = e.response?.data?.error || 'Não foi possível carregar o histórico.'; }
  finally { loading.value = false; }
};
watch(() => props.inbox.id, () => {
  generation += 1;
  catalog.value = { templates: [], teams: [] };
  selected.value = null;
  entries.value = [];
  page.value = 1;
  activeTab.value = 'templates';
  load();
}, { immediate: true });
watch([activeTab, page], () => { if (activeTab.value === 'logs') loadLogs(); });
</script>
<template>
  <section class="mx-6 mb-8 max-w-6xl space-y-4">
    <header class="flex gap-4 justify-between items-start flex-wrap">
      <div>
        <h2 class="text-lg font-semibold mb-1">Templates WhatsApp</h2>
        <p class="text-sm text-n-slate-11 mb-1">{{ inbox.name }} · Catálogo exclusivo desta caixa.</p>
        <p class="text-xs text-n-slate-11 mb-0">Última sincronização concluída: {{ dateLabel(catalog.last_sync_at) }}</p>
      </div>
      <Button :label="syncing ? 'Sincronizando...' : 'Sincronizar agora'" icon="i-lucide-refresh-cw" :disabled="syncing || loading || saving" @click="sync" />
    </header>
    <p class="text-sm rounded-lg bg-n-alpha-black2 p-3">O agente escolhe o modelo na conversa. Somente modelos aprovados e liberados para a equipe podem ser enviados. O envio não libera mensagem comum: é necessária uma resposta do cliente.</p>
    <div v-if="error || catalog.sync_error" class="rounded-lg p-3 bg-n-ruby-2 text-n-ruby-11 text-sm" role="alert">{{ error || catalog.sync_error }}</div>
    <div v-if="success" class="rounded-lg p-3 bg-n-teal-2 text-n-teal-11 text-sm" role="status">{{ success }}</div>
    <nav class="flex gap-2" aria-label="Templates WhatsApp">
      <Button label="Modelos e permissões" :variant="activeTab === 'templates' ? 'solid' : 'ghost'" @click="activeTab = 'templates'" />
      <Button label="Histórico de envios" :variant="activeTab === 'logs' ? 'solid' : 'ghost'" @click="activeTab = 'logs'" />
    </nav>
    <p v-if="loading" class="text-sm" role="status">Carregando...</p>
    <div v-if="activeTab === 'templates'" class="space-y-4">
      <div class="flex flex-wrap gap-2">
        <input v-model="query" type="search" placeholder="Pesquisar modelo" aria-label="Pesquisar modelo" class="!mb-0 !w-auto flex-1" />
        <select v-model="status" aria-label="Status" class="!w-auto !mb-0"><option value="">Todos os status</option><option v-for="item in statuses" :key="item">{{ item }}</option></select>
        <select v-model="category" aria-label="Categoria" class="!w-auto !mb-0"><option value="">Todas as categorias</option><option v-for="item in categories" :key="item">{{ item }}</option></select>
        <select v-model="language" aria-label="Idioma" class="!w-auto !mb-0"><option value="">Todos os idiomas</option><option v-for="item in languages" :key="item">{{ item }}</option></select>
      </div>
      <div class="grid gap-4 lg:grid-cols-2">
        <div class="border border-n-weak rounded-lg overflow-y-auto max-h-[38rem] divide-y divide-n-weak">
          <button v-for="template in filtered" :key="template.jrc.key" type="button" class="w-full text-left p-4 hover:bg-n-alpha-black2" :class="{ 'bg-n-alpha-black2': selected?.jrc.key === template.jrc.key }" @click="choose(template)">
            <strong class="text-sm">{{ template.jrc.favorite ? '★ ' : '' }}{{ template.name }}</strong>
            <span class="block text-xs text-n-slate-11 mt-1">{{ template.category }} · {{ template.language }} · {{ template.status }}</span>
            <span v-if="!template.jrc.enabled" class="text-xs text-n-ruby-11">Desabilitado internamente</span>
            <span v-else-if="!template.jrc.supported" class="text-xs text-n-amber-11">Formato não suportado neste formulário</span>
          </button>
          <p v-if="!loading && !filtered.length" class="p-4 text-sm text-n-slate-11">Nenhum modelo encontrado. Use Sincronizar agora para consultar o provedor.</p>
        </div>
        <form v-if="selected" class="border border-n-weak rounded-lg p-4 space-y-4" @submit.prevent="save">
          <h3 class="font-semibold text-sm">{{ selected.name }}</h3>
          <div class="rounded-lg bg-n-alpha-black2 p-3 text-sm whitespace-pre-wrap">{{ component(selected, 'HEADER')?.text }}<br v-if="component(selected, 'HEADER')?.text" />{{ component(selected, 'BODY')?.text }}<p v-if="component(selected, 'FOOTER')?.text" class="text-xs mt-2 mb-0">{{ component(selected, 'FOOTER').text }}</p></div>
          <label class="flex items-center gap-2 text-sm"><input v-model="rule.enabled" type="checkbox" class="!mb-0" /> Liberado para uso no JRC</label>
          <label class="flex items-center gap-2 text-sm"><input v-model="rule.favorite" type="checkbox" class="!mb-0" /> Favorito para as equipes autorizadas</label>
          <label class="block text-sm">Equipes autorizadas
            <select v-model="rule.team_ids" multiple class="mt-1 !mb-0 min-h-24"><option v-for="team in catalog.teams" :key="team.id" :value="team.id">{{ team.name }}</option></select>
            <small class="block text-n-slate-11 mt-1">Sem seleção: todas as equipes da caixa. Uma conversa sem equipe não acessa modelos restritos.</small>
          </label>
          <div v-if="selected.jrc.variables.length" class="space-y-2">
            <h4 class="text-sm font-semibold">Preenchimento automático</h4>
            <label v-for="key in selected.jrc.variables" :key="key" class="block text-sm">{{ key }}
              <select v-model="rule.bindings[key]" class="!mb-0"><option :value="undefined">Manual / sugestão pelo nome da variável</option><option v-for="source in catalog.variable_sources" :key="source" :value="source">{{ sourceLabels[source] || source }}</option></select>
            </label>
            <p class="text-xs text-n-slate-11">O agente pode revisar os valores antes de enviar. Variáveis numéricas, como <span v-pre>{{1}}</span>, só são preenchidas automaticamente quando configuradas aqui.</p>
          </div>
          <Button type="submit" :label="saving ? 'Salvando...' : 'Salvar permissões'" :disabled="saving || syncing" />
        </form>
        <div v-else class="rounded-lg border border-dashed border-n-weak p-8 text-sm text-n-slate-11">Selecione um modelo para visualizar o texto, definir equipes, favoritos e variáveis.</div>
      </div>
    </div>
    <div v-else class="space-y-3">
      <p class="text-xs text-n-slate-11">Registro técnico restrito aos administradores. Os horários de status indicam o registro no JRC.</p>
      <div class="overflow-x-auto border rounded-lg border-n-weak">
        <table class="w-full text-sm text-left">
          <thead><tr><th class="p-3">Data / agente</th><th class="p-3">Conversa / modelo</th><th class="p-3">Status / provedor</th></tr></thead>
          <tbody><tr v-for="entry in entries" :key="entry.id" class="border-t border-n-weak">
            <td class="p-3 align-top">{{ dateLabel(entry.created_at) }}<br /><span class="text-xs text-n-slate-11">{{ entry.agent_name || 'Sistema' }}</span></td>
            <td class="p-3 align-top">#{{ entry.conversation_id }} · {{ entry.template.name }}<br /><span class="text-xs text-n-slate-11">{{ entry.template.language }}</span><details class="text-xs mt-1"><summary class="cursor-pointer">Variáveis e auditoria</summary><pre class="whitespace-pre-wrap break-all mt-2">{{ JSON.stringify({ parametros: entry.template.processed_params, auditoria: entry.audit }, null, 2) }}</pre></details></td>
            <td class="p-3 align-top"><strong>{{ entry.audit?.status || entry.status }}</strong><p class="text-xs break-all mb-0">{{ entry.provider_message_id || 'Sem confirmação do provedor' }}</p><p v-if="entry.error" class="text-xs text-n-ruby-11 mt-1 mb-0">{{ entry.error }}</p></td>
          </tr></tbody>
        </table>
        <p v-if="!loading && !entries.length" class="p-4 text-sm">Nenhum envio de modelo nesta página.</p>
      </div>
      <div class="flex items-center justify-end gap-3"><Button label="Anterior" variant="ghost" :disabled="page <= 1 || loading" @click="page -= 1" /><span class="text-sm">Página {{ page }}</span><Button label="Próxima" variant="ghost" :disabled="entries.length < 50 || loading" @click="page += 1" /></div>
    </div>
  </section>
</template>
