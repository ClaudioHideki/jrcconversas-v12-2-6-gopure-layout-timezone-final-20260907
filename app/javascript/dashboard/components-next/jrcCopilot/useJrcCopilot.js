import { ref } from 'vue';

const isOpen = ref(false);
const pendingPrompt = ref('');

export const useJrcCopilot = () => {
  const open = () => {
    isOpen.value = true;
  };
  const close = () => {
    isOpen.value = false;
  };
  const toggle = () => {
    isOpen.value = !isOpen.value;
  };
  const openWithPrompt = prompt => {
    pendingPrompt.value = String(prompt || '').trim();
    isOpen.value = true;
  };
  const consumePrompt = () => {
    const value = pendingPrompt.value;
    pendingPrompt.value = '';
    return value;
  };

  return {
    isOpen,
    pendingPrompt,
    open,
    close,
    toggle,
    openWithPrompt,
    consumePrompt,
  };
};
