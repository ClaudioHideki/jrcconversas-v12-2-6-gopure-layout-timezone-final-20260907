/* eslint-disable no-console */
import { dashboardAPI } from '../../../api/crm';

export default {
  namespaced: true,
  state: {
    metrics: {},
    isLoading: false,
    error: null,
  },
  getters: {
    metrics: state => state.metrics,
    isLoading: state => state.isLoading,
    error: state => state.error,
  },
  mutations: {
    SET_METRICS(state, payload) {
      state.metrics = payload;
    },
    SET_LOADING(state, payload) {
      state.isLoading = payload;
    },
    SET_ERROR(state, payload) {
      state.error = payload;
    },
  },
  actions: {
    async fetchMetrics({ commit }, params) {
      commit('SET_LOADING', true);
      commit('SET_ERROR', null);
      try {
        const response = await dashboardAPI.metrics(params);
        commit('SET_METRICS', response.data);
      } catch (error) {
        console.error(error);
        commit(
          'SET_ERROR',
          error.response?.data?.error ||
            error.response?.data?.message ||
            'Não foi possível carregar os indicadores do CRM.'
        );
      } finally {
        commit('SET_LOADING', false);
      }
    },
  },
};
