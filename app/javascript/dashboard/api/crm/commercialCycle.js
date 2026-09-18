/* global axios */
import ApiClient from '../ApiClient';
const make = path => { const api=new ApiClient(`crm/${path}`,{accountScoped:true}); api.list=params=>axios.get(api.url,{params}); api.create=data=>axios.post(api.url,data); api.update=(id,data)=>axios.patch(`${api.url}/${id}`,data); return api; };
export const salesOrdersAPI=make('sales_orders');
export const contractsAPI=make('contracts');
contractsAPI.pdf=id=>axios.get(`${contractsAPI.url}/${id}/pdf`,{responseType:'blob'});
export const commissionsAPI=make('commissions');
export const goalsAPI=make('goals');

export const customersAPI = (() => { const api=new ApiClient('crm/customers',{accountScoped:true}); api.show=id=>axios.get(`${api.url}/${id}`); return api; })();
