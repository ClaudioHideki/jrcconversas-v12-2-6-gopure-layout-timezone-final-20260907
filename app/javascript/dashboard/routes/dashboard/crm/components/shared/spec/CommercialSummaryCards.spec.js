import { mount } from '@vue/test-utils';
import CommercialSummaryCards from '../CommercialSummaryCards.vue';
import { commercialSummaryCards } from '../commercialSummaryCards';
import messages from 'dashboard/i18n/locale/en/crm.json';

it('keeps active revenue separate from deal wins and public signatures in the UI and CSV source', () => {
  const summary = {
    leads: { new: 2, qualified: 3, converted: 1 },
    deals: {
      open: { value_cents: 20000 },
      won: { value_cents: 90000 },
      lost: { value_cents: 1000 },
    },
    proposals_sent_count: 4,
    orders: { active_count: 1, pending_count: 2, revenue_cents: 12000 },
    signed_proposals: { count: 2, value_cents: 30000 },
  };
  const wrapper = mount(CommercialSummaryCards, { props: { summary } });
  const cards = wrapper.findAll('article');
  expect(cards).toHaveLength(6);
  expect(cards[0].text()).toContain('Qualificados');
  expect(cards[0].find('h3').text()).toBe('Leads cadastrados');
  expect(cards[0].find('strong').text()).toBe('6');
  expect(cards[4].text().replaceAll('\u00a0', ' ')).toContain('R$ 120,00');
  expect(cards[5].text().replaceAll('\u00a0', ' ')).toContain('R$ 300,00');
  expect(wrapper.text()).not.toContain('MRR');
  const csv = commercialSummaryCards(
    summary,
    key => key.split('.').reduce((o, k) => o[k], messages),
    cents => String(cents)
  );
  expect(csv.find(card => card.key === 'REVENUE').value).toBe('12000');
  expect(csv.find(card => card.key === 'SIGNED').value).toBe('30000');
  wrapper.unmount();
});
