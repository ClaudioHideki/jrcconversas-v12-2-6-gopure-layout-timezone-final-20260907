import { visibleSidebarSections } from './temporaryVisibility';

export const buildSidebarSections = ({
  menuItems,
  legacyMenuItems,
  unified,
  t,
  universityLink,
}) => {
  const itemByName = new Map(menuItems.map(item => [item.name, item]));
  const take = names => names.map(name => itemByName.get(name)).filter(Boolean);

  const mappedNames = new Set([
    'JRC Cockpit',
    'Inbox',
    'Conversation',
    'JRC Email Center',
    'JRC Calls Center',
    'JRC Call Center',
    'WhatsApp Calling',
    'Contacts',
    'JRC AI Agents',
    'JRC AI Insights',
    'Captain',
    'JRC Intelligent Automation',
    'JRC Flows',
    'Companies',
    'CRM',
    'Sales',
    'JRC Campaigns',
    'Reports',
    'JRC AI Administration',
    'Video Conference',
    'Settings',
    'Customers',
    'JRC Broker Connections',
    'JRC Service Desk',
    'JRC Service Desk Structure',
    'JRC Approvals',
  ]);
  const legacyExtras = legacyMenuItems
    .filter(item => item && !mappedNames.has(item.name))
    .map(item => ({ ...item }))
    .filter(Boolean);

  const sharedSections = [
    {
      name: 'intelligence',
      label: t('JRC_CONTACT_CENTER.NAVIGATION.INTELIGENCIA'),
      items: take([
        'JRC Flows',
        'JRC AI Agents',
        'JRC AI Insights',
        'Captain',
        'JRC Intelligent Automation',
      ]),
    },
    {
      name: 'administration',
      label: t('JRC_CONTACT_CENTER.NAVIGATION.ADMINISTRACAO'),
      items: take([
        'JRC Service Desk Structure',
        'JRC Approvals',
        'JRC AI Administration',
        'Settings',
      ]),
    },
    {
      name: 'learning',
      label: t('JRC_HOME.LEARNING'),
      items: [universityLink],
    },
    {
      name: 'legacy-tools',
      label: t('JRC_CONTACT_CENTER.NAVIGATION.OUTROS_RECURSOS'),
      items: legacyExtras,
    },
  ];

  if (unified) {
    return visibleSidebarSections([
      {
        name: 'attendance',
        label: t('JRC_CONTACT_CENTER.NAV_GROUPS.ATTENDANCE'),
        items: take(['JRC Call Center', 'Inbox', 'JRC Cockpit']),
      },
      {
        name: 'crm',
        label: t('JRC_CONTACT_CENTER.VISUAL.CRM'),
        items: take(['CRM', 'Relationship']),
      },
      {
        name: 'operations',
        label: t('JRC_CONTACT_CENTER.NAVIGATION.OPERACOES'),
        items: take([
          'JRC Service Desk',
          'JRC Projects',
          'JRC Campaigns',
          'Reports',
        ]),
      },
      {
        name: 'additional-channels',
        label: t('JRC_CONTACT_CENTER.NAVIGATION.CANAIS_ADICIONAIS'),
        items: take([
          'WhatsApp Calling',
          'JRC Broker Connections',
          'Video Conference',
        ]),
      },
      {
        name: 'relationships',
        label: t('JRC_CONTACT_CENTER.NAVIGATION.RELACIONAMENTOS'),
        items: take(['Customers', 'Companies']),
      },
      ...sharedSections,
    ]);
  }

  return visibleSidebarSections([
    {
      name: 'attendance',
      label: 'Atendimento',
      items: take([
        'JRC Cockpit',
        'Inbox',
        'Conversation',
        'JRC Broker Connections',

        'JRC Email Center',
        'JRC Calls Center',
        'Contacts',
        'JRC Service Desk',
        'CRM',
        'Sales',
        'JRC Campaigns',
        'Reports',
        'Video Conference',
      ]),
    },
    {
      name: 'intelligence',
      label: 'Inteligencia',
      items: take([
        'JRC Flows',
        'JRC AI Agents',
        'JRC AI Insights',
        'Captain',
        'JRC Intelligent Automation',
      ]),
    },
    {
      name: 'relationships',
      label: 'Relacionamentos',
      items: take([
        'Customers',
        'Companies',
        'Relationship',
        'JRC Projects',
        'JRC Agenda',
      ]),
    },

    {
      name: 'administration',
      label: 'Administracao',
      items: take([
        'JRC Service Desk Structure',
        'JRC Approvals',
        'JRC AI Administration',
        'Settings',
      ]),
    },
    {
      name: 'learning',
      label: t('JRC_HOME.LEARNING'),
      items: [universityLink],
    },
    { name: 'legacy-tools', label: 'Outros recursos', items: legacyExtras },
  ]);
};
