import { defineConfig, mergeConfig } from 'vitest/config';
import nico from './vitest.nico.config';

export default mergeConfig(
  nico,
  defineConfig({
    test: {
      environment: 'jsdom',
      mockReset: true,
      clearMocks: true,
      include: [
        'app/javascript/dashboard/routes/dashboard/jrcOperations/**/*.spec.js',
        'app/javascript/dashboard/routes/dashboard/jrcProjects/**/*.spec.js',
      ],
    },
  })
);
