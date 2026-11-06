// Carry only the shared, server-validated filters between the summary and board.
export const commercialFilterQuery = (filters = {}) =>
  Object.fromEntries(
    ['pipeline_id', 'owner_id', 'start_date', 'end_date']
      .filter(
        key =>
          ['string', 'number'].includes(typeof filters[key]) &&
          filters[key] !== ''
      )
      .map(key => [key, String(filters[key])])
  );

export const commercialFiltersFromQuery = (query = {}) => {
  const values = commercialFilterQuery(query);
  return {
    period: values.start_date || values.end_date ? 'custom' : 'all',
    owner_id: values.owner_id || '',
    pipeline_id: values.pipeline_id || '',
    start_date: values.start_date || '',
    end_date: values.end_date || '',
  };
};
