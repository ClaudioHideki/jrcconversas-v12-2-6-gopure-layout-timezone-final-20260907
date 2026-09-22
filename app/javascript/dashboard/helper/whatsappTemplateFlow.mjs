// Pure helpers shared by the UI and the standalone regression tests.
export const component = (template, type) =>
  (template?.components || []).find(item => item.type?.toUpperCase() === type);

export const variableKeys = text => {
  const keys = [...String(text || '').matchAll(/\{\{\s*([^{}]+?)\s*\}\}/g)]
    .map(match => match[1].trim());
  const unique = [...new Set(keys)];
  return unique.every(key => /^\d+$/.test(key))
    ? unique.sort((a, b) => Number(a) - Number(b)) : unique;
};

export function buildJrcTemplateParameters(template, defaults = {}) {
  const params = {};
  for (const type of ['HEADER', 'BODY']) {
    const item = component(template, type);
    if (!item) continue;
    const section = type.toLowerCase();
    if (type === 'HEADER' && ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(item.format)) {
      params.header = { media_type: item.format.toLowerCase(), media_url: '', media_name: '' };
    } else {
      const keys = variableKeys(item.text);
      if (keys.length) params[section] = Object.fromEntries(keys.map(key => [key, defaults[`${section}.${key}`] || '']));
    }
  }
  const buttons = component(template, 'BUTTONS')?.buttons;
  if (buttons?.length) {
    params.buttons = buttons.map((button, index) => ({
      type: button.type.toLowerCase(),
      ...(button.type === 'COPY_CODE' || variableKeys(button.url).length
        ? { parameter: defaults[`buttons.${index}`] || '' } : {}),
    }));
  }
  return params;
}

export function templateValidationErrors(template, params = {}) {
  const errors = [];
  const validText = (value, label, max = 1000) => {
    if (typeof value !== 'string' || !value.trim()) errors.push(`Preencha ${label}.`);
    else if (value.length > max) errors.push(`${label}: máximo de ${max} caracteres.`);
    else if (/[\r\n\t]/.test(value)) errors.push(`Remova quebras de linha de ${label}.`);
  };
  for (const type of ['HEADER', 'BODY']) {
    const item = component(template, type);
    if (!item) continue;
    const section = type.toLowerCase();
    if (type === 'HEADER' && ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(item.format)) {
      try {
        const url = new URL(params.header?.media_url || '');
        if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password || url.href.length > 2000) throw new Error();
      } catch {
        errors.push('Informe uma URL HTTP ou HTTPS válida para a mídia.');
      }
    } else {
      variableKeys(item.text).forEach(key => validText(params[section]?.[key], `${section}.${key}`));
    }
  }
  (component(template, 'BUTTONS')?.buttons || []).forEach((button, index) => {
    if (button.type === 'COPY_CODE' || variableKeys(button.url).length) {
      validText(params.buttons?.[index]?.parameter, `botão ${index + 1}`, button.type === 'COPY_CODE' ? 15 : 1000);
    }
  });
  return errors;
}

export const renderTemplatePart = (text, params = {}) =>
  String(text || '').replace(/\{\{\s*([^{}]+?)\s*\}\}/g, (match, key) => params[key.trim()] || match);

// Time is derived from a server snapshot + monotonic elapsed time, not the
// operator's wall clock. Closed/unknown snapshots can never enable free text.
export function windowState(snapshot, elapsedMs = 0) {
  const closed = { ...(snapshot || {}), can_send_free_message: false, remaining_seconds: 0, window_status: snapshot?.window_status || 'UNKNOWN' };
  if (!snapshot || snapshot.can_send_free_message !== true || snapshot.window_status !== 'OPEN') return closed;
  const expires = Date.parse(snapshot.expires_at);
  const server = Date.parse(snapshot.server_time);
  if (!Number.isFinite(expires) || !Number.isFinite(server)) return { ...closed, window_status: 'UNKNOWN' };
  if (!Number.isFinite(elapsedMs)) return { ...closed, window_status: 'UNKNOWN' };
  const remaining = Math.max(0, Math.ceil((expires - server - Math.max(0, elapsedMs)) / 1000));
  return { ...snapshot, can_send_free_message: remaining > 0, remaining_seconds: remaining, window_status: remaining > 0 ? 'OPEN' : 'CLOSED' };
}

export function friendlyWhatsappError(error) {
  const text = String(error || '');
  if (/131047|WHATSAPP_WINDOW_CLOSED|outside.*(window|24)|24.hour/i.test(text)) return 'A janela do WhatsApp encerrou. Escolha um modelo aprovado e aguarde a resposta do cliente.';
  if (/132001|TEMPLATE_NOT_AVAILABLE|not found or invalid template/i.test(text)) return 'Este modelo não está disponível para esta caixa. Escolha outro modelo ou solicite uma sincronização ao administrador.';
  if (/132015|132016/.test(text)) return 'Este modelo foi pausado ou desativado pelo WhatsApp. Escolha outro modelo aprovado.';
  if (/132000|132012|INVALID_TEMPLATE_PARAMETERS/.test(text)) return 'As variáveis não correspondem ao modelo. Revise os campos antes de enviar.';
  if (/131026/.test(text)) return 'O WhatsApp não conseguiu entregar esta mensagem. Verifique o contato e a disponibilidade do número.';
  if (/131030|190:|133010/.test(text)) return 'A conexão desta caixa precisa ser revisada pelo administrador.';
  if (/131048|131049/.test(text)) return 'O WhatsApp limitou este envio. Não repita o envio automaticamente; revise o contato e o uso do modelo.';
  return text || 'Não foi possível enviar a mensagem.';
}
