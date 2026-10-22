import { buildSidebarSections } from '../sections';

const customerRoutes = [
  'companies',
  'contacts',
  'segments',
  'groups',
  'imports',
  'active',
];
const customers = {
  name: 'Customers',
  children: customerRoutes.map(name => ({ name, to: `/customers/${name}` })),
};
const makeSections = (unified, enabled) =>
  buildSidebarSections({
    unified,
    menuItems: [
      { name: 'CRM' },
      { name: 'Inbox' },
      { name: 'JRC Projects' },
      { name: 'JRC Campaigns' },
      { name: 'Settings' },
      ...(enabled ? [customers] : []),
    ],
    legacyMenuItems: [],
    t: key => key,
    universityLink: { name: 'University' },
  });

describe('sidebar sections and customer directory availability', () => {
  it.each([true, false])(
    'keeps the authorized customer group and its routes with unified=%s',
    unified => {
      const sections = makeSections(unified, true);
      const relationship = sections.find(
        section => section.name === 'relationships'
      );
      expect(relationship?.items).toContain(customers);
      expect(
        relationship.items.find(item => item.name === 'Customers').children
      ).toEqual(customers.children);
      expect(
        sections
          .flatMap(section => section.items)
          .filter(item => item.name === 'Customers')
      ).toHaveLength(1);
    }
  );

  it.each([true, false])(
    'does not introduce a customer menu when the feature is unavailable, unified=%s',
    unified => {
      const sections = makeSections(unified, false);
      expect(
        sections
          .flatMap(section => section.items)
          .some(item => item.name === 'Customers')
      ).toBe(false);
      expect(sections.every(section => section.items.length > 0)).toBe(true);
    }
  );

  it('preserves the existing unified CRM, attendance, projects and campaign entries', () => {
    const names = makeSections(true, true).flatMap(section =>
      section.items.map(item => item.name)
    );
    expect(names).toEqual(
      expect.arrayContaining([
        'CRM',
        'Inbox',
        'JRC Projects',
        'JRC Campaigns',
        'Settings',
      ])
    );
    expect(customers.children.map(child => child.name)).toEqual(customerRoutes);
  });
});
