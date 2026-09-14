export const AVAILABILITY_STATUSES = [
  { label: 'Disponível', value: 'online', color: 'bg-n-teal-9' },
  { label: 'Indisponível', value: 'offline', color: 'bg-n-slate-9' },
  { label: 'Reunião', value: 'meeting', color: 'bg-n-blue-9' },
  { label: 'Feedback', value: 'feedback', color: 'bg-n-violet-9' },
  { label: 'Fim do turno', value: 'end_shift', color: 'bg-n-gray-9' },
  { label: 'Treinamento', value: 'training', color: 'bg-n-iris-9' },
  { label: 'Pausa banheiro', value: 'bathroom_break', color: 'bg-[#06b6d4]' },
  { label: 'Pausa almoço', value: 'lunch_break', color: 'bg-n-amber-9' },
  { label: 'Chamada Manual', value: 'manual_call', color: 'bg-n-ruby-9' },
];

// Keep existing busy accounts readable while the menu offers specific reasons.
export const LEGACY_BUSY_STATUS = {
  label: 'Ocupado',
  value: 'busy',
  color: 'bg-n-amber-9',
};

export const getAvailabilityStatus = value =>
  [LEGACY_BUSY_STATUS, ...AVAILABILITY_STATUSES].find(
    status => status.value === value
  ) || AVAILABILITY_STATUSES.find(status => status.value === 'offline');
