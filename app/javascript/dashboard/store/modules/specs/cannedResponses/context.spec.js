import module from '../../cannedResponse';
import API from 'dashboard/api/cannedResponse';

vi.mock('dashboard/api/cannedResponse', () => ({
  default: { get: vi.fn(), accountIdFromRoute: '1' },
}));

it('does not replace the active account catalog with a late response from the previous account', async () => {
  let finish;
  API.accountIdFromRoute = '1';
  API.get.mockImplementationOnce(
    () =>
      new Promise(resolve => {
        finish = resolve;
      })
  );
  const commit = vi.fn();
  const pending = module.actions.getCannedResponse(
    { commit },
    { searchKey: '' }
  );
  API.accountIdFromRoute = '2';
  finish({ data: [{ id: 4, account_id: 1, content: 'Previous tenant' }] });
  await pending;
  expect(commit.mock.calls.some(([, data]) => Array.isArray(data))).toBe(false);
  expect(commit).toHaveBeenLastCalledWith(expect.any(String), {
    fetchingList: false,
  });
});
