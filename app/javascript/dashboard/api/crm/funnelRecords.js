/* global axios */
import ApiClient from '../ApiClient';

const funnelRecordsAPI = new ApiClient('crm/funnel_records', {
  accountScoped: true,
});
funnelRecordsAPI.list = params => axios.get(funnelRecordsAPI.url, { params });
export default funnelRecordsAPI;
