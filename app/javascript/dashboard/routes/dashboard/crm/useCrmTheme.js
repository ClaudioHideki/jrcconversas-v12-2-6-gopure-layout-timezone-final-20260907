import { computed } from 'vue';
import { useStore } from 'vuex';
import { crmControlClasses as baseControls } from './crmControlClasses';

export const isGoPureAccount = account => {
  const configured = account?.custom_attributes?.crm_theme;
  if (configured) return configured === 'gopure';
  return account?.name?.toLowerCase().replace(/\s/g, '') === 'gopure';
};

// The GoPure palette is scoped to the account's CRM surfaces, including dialogs.
// Other accounts keep the existing CRM colors.
const goPureControls =
  '[&_:is(button,a).bg-n-brand:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-n-blue-9:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-blue-600:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-blue-700:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-n-iris-9:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-violet-600:not(:disabled)]:!bg-[#047857] [&_:is(button,a).bg-indigo-600:not(:disabled)]:!bg-[#047857] [&_.bg-blue-600]:!bg-[#047857] [&_.bg-emerald-600]:!bg-[#059669] [&_.bg-blue-50]:!bg-[#ecfdf5] [&_.bg-blue-100]:!bg-[#d1fae5] [&_.text-blue-700]:!text-[#047857] [&_.text-blue-800]:!text-[#065f46] [&_.text-n-brand]:!text-[#047857] [&_:is(button,a,input,select,textarea):focus-visible]:!outline-[#047857]';
export const useCrmTheme = () => {
  const store = useStore();
  const isGoPure = computed(() =>
    isGoPureAccount({
      ...store.getters.getCurrentAccount,
      ...store.getters['accounts/getAccount']?.(
        store.getters.getCurrentAccountId
      ),
    })
  );
  const crmControlClasses = computed(() =>
    isGoPure.value
      ? [
          baseControls
            .replaceAll('!bg-n-blue-11', '!bg-[#047857]')
            .replaceAll('!bg-n-iris-11', '!bg-[#047857]')
            .replaceAll('!outline-n-blue-11', '!outline-[#047857]'),
          goPureControls,
        ]
      : baseControls
  );
  return { isGoPure, crmControlClasses };
};
