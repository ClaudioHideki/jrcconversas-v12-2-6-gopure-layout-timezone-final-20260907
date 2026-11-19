import { defineConfig } from 'vitest/config';
import base from './vitest.quickReplies.config';

base.test = {
  ...base.test,
  include: [
    'app/javascript/dashboard/components-next/NewConversation/specs/*.spec.js',
    'app/javascript/dashboard/components-next/NewConversation/helpers/specs/*.spec.js',
  ],
};

export default defineConfig(base);
