import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import API from '../cannedResponse';

let originalAxios;
let get;
beforeEach(() => {
  originalAxios = window.axios;
  get = vi.fn().mockResolvedValue({ data: new Blob(['synthetic']) });
  window.axios = { get };
});
afterEach(() => {
  window.axios = originalAxios;
});

it('sends the reviewed revision and attachment identity with the scoped byte request', async () => {
  const expected = {
    revision: 'synthetic-reviewed-revision',
    attachment_id: 41,
  };
  await API.file(3, 7, expected);
  expect(get).toHaveBeenCalledWith(
    '/api/v1/accounts/7/canned_responses/3/file',
    {
      responseType: 'blob',
      params: expected,
    }
  );
});

it('keeps the existing file consumer compatible when no preview identity was supplied', async () => {
  await API.file(3, 7);
  expect(get).toHaveBeenCalledWith(
    '/api/v1/accounts/7/canned_responses/3/file',
    {
      responseType: 'blob',
      params: {},
    }
  );
});

it('uploads the file and text together using the native multipart create and update endpoints', async () => {
  const post = vi.fn().mockResolvedValue({ data: {} });
  const patch = vi.fn().mockResolvedValue({ data: {} });
  window.axios = { get, post, patch };
  window.history.replaceState(
    {},
    '',
    '/app/accounts/7/settings/canned-responses'
  );
  const file = new File(['synthetic'], 'reviewed.pdf', {
    type: 'application/pdf',
  });
  await API.create({ short_code: 'synthetic', content: 'Reviewed', file });
  const values = post.mock.calls[0][1];
  expect(values).toBeInstanceOf(FormData);
  expect(values.get('canned_response[file]')).toBe(file);
  expect(values.get('canned_response[content]')).toBe('Reviewed');
  await API.update(3, { content: 'Preserved', remove_file: true });
  expect(patch.mock.calls[0][1].get('canned_response[remove_file]')).toBe(
    'true'
  );
});

it('escapes the search shortcut and rejects an invalid explicit account', async () => {
  await API.get({ searchKey: '/a&private=true', accountId: 7 });
  expect(get).toHaveBeenCalledWith(
    '/api/v1/accounts/7/canned_responses?search=%2Fa%26private%3Dtrue'
  );
  expect(() => API.file(3, 'other-account')).toThrow('INVALID_ACCOUNT');
});
