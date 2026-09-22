/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  whatsappWindow(conversationID) {
    return axios.get(`${this.url}/${conversationID}/whatsapp_window`);
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  getUnreadCounts() {
    return axios.get(`${this.url}/unread_counts`);
  }
}

export default new ConversationApi();
