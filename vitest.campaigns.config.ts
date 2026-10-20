import { defineConfig, mergeConfig } from 'vitest/config';
import nico from './vitest.nico.config';

export default mergeConfig(
  nico,
  defineConfig({
    test: {
      environment: 'jsdom',
      include: [
        'app/javascript/dashboard/routes/dashboard/jrcCampaigns/specs/*.spec.js',
      ],
    },
  })
);
