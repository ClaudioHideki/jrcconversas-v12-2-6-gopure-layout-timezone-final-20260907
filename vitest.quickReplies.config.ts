import { defineConfig, mergeConfig } from 'vitest/config';
import { realpathSync } from 'node:fs';
import base from './vitest.config';

const config = mergeConfig(
  base,
  defineConfig({
    resolve: { dedupe: ['vue'] },
    server: { fs: { allow: [process.cwd(), realpathSync('node_modules')] } },
    test: {
      // VueUse must use the same Vue instance as the native dialog and its refs.
      server: { deps: { inline: [/@vueuse/, 'vue-demi'] } },
    },
  })
);

config.test = {
  ...config.test,
  include: [
    'app/javascript/dashboard/api/specs/cannedResponseRevision.spec.js',
    'app/javascript/dashboard/components/widgets/conversation/specs/*.spec.js',
    'app/javascript/dashboard/components/widgets/WootWriter/spec/*.spec.js',
    'app/javascript/dashboard/routes/dashboard/settings/canned/specs/*.spec.js',
    'app/javascript/dashboard/mixins/specs/fileUploadMixin.spec.js',
    'app/javascript/dashboard/helper/specs/editorHelper.spec.js',
    'app/javascript/dashboard/store/modules/specs/cannedResponses/*.spec.js',
  ],
};

export default defineConfig(config);
