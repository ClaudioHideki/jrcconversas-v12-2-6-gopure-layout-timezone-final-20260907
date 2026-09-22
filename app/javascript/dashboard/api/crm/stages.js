/* global axios */
import ApiClient from '../ApiClient';

class StagesAPI extends ApiClient {
  constructor() {
    super('crm/stages', { accountScoped: true });
  }

  reorder(stages) { return axios.post(`${this.url}/reorder`, { stages }); }

  list(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new StagesAPI();
