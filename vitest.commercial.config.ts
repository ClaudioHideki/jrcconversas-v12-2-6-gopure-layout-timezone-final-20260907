import { defineConfig, mergeConfig } from 'vitest/config';
import nico from './vitest.nico.config';

export default mergeConfig(
  nico,
  defineConfig({
    cacheDir: './tmp/vitest-commercial',
    test: {
      environment: 'jsdom',
      mockReset: true,
      clearMocks: true,
      include: [
        'app/javascript/dashboard/routes/dashboard/crm/specs/*.spec.js',
        'app/javascript/dashboard/api/specs/contacts.spec.js',
        'app/javascript/dashboard/store/modules/specs/contacts/*.spec.js',
      ],
    },
  })
);
