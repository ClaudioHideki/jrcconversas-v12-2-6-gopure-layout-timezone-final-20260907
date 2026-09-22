/* global axios */
import ApiClient from './ApiClient';
class WhatsappTemplatesAPI extends ApiClient {
  constructor() { super('inboxes', { accountScoped: true }); }
  catalog(inboxId, params = {}) { return axios.get(`${this.url}/${inboxId}/whatsapp_templates`, { params }); }
  refresh(inboxId) { return axios.post(`${this.url}/${inboxId}/refresh_whatsapp_templates`, {}, { timeout: 120000 }); }
  saveRule(inboxId, templateKey, rule) { return axios.patch(`${this.url}/${inboxId}/update_whatsapp_template_rule`, { template_key: templateKey, rule }); }
  logs(inboxId, page = 1) { return axios.get(`${this.url}/${inboxId}/whatsapp_template_logs`, { params: { page } }); }
}
export default new WhatsappTemplatesAPI();
