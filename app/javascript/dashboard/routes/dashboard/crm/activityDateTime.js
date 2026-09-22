// datetime-local is interpreted by the CRM API in the ACCOUNT timezone.
// Do not convert due_at to the browser timezone: editing would change the instant.
export const activityDateTimeInput = activity => {
  const local = activity?.due_at_input;
  if (typeof local === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(local)) {
    return local;
  }
  // Backward-compatible with the account-local display field from older servers.
  const parts = /^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2})$/.exec(
    activity?.due_at_display || ''
  );
  return parts ? `${parts[3]}-${parts[2]}-${parts[1]}T${parts[4]}:${parts[5]}` : '';
};
