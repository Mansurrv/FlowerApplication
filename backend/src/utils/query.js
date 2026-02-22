const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

const parseNumber = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

const parseSort = (sort, defaultSort) => {
  if (typeof sort === "string" && sort.trim().length > 0) {
    return sort
      .split(",")
      .map((field) => field.trim())
      .filter(Boolean)
      .join(" ");
  }

  if (typeof defaultSort === "string" && defaultSort.trim().length > 0) {
    return defaultSort;
  }

  return null;
};

const parseFields = (fields) => {
  if (typeof fields !== "string" || fields.trim().length === 0) {
    return null;
  }

  return fields
    .split(",")
    .map((field) => field.trim())
    .filter(Boolean)
    .join(" ");
};

const parsePagination = (queryParams, options = {}) => {
  const pageProvided =
    queryParams.page !== undefined || queryParams.limit !== undefined;

  if (!pageProvided) {
    return { paginate: false };
  }

  const defaultLimit = options.defaultLimit || DEFAULT_LIMIT;
  const maxLimit = options.maxLimit || MAX_LIMIT;

  const page = Math.max(1, parseNumber(queryParams.page, 1));
  let limit = parseNumber(queryParams.limit, defaultLimit);
  limit = Math.max(1, Math.min(maxLimit, limit));

  return {
    paginate: true,
    page,
    limit,
    skip: (page - 1) * limit,
  };
};

const applyQueryOptions = (mongooseQuery, queryParams, options = {}) => {
  let query = mongooseQuery;

  const sort = parseSort(queryParams.sort, options.defaultSort);
  if (sort) {
    query = query.sort(sort);
  }

  const fields = parseFields(queryParams.fields);
  if (fields) {
    query = query.select(fields);
  }

  const pagination = parsePagination(queryParams, options);
  if (pagination.paginate) {
    query = query.skip(pagination.skip).limit(pagination.limit);
  }

  return {
    query,
    pagination: pagination.paginate
      ? { page: pagination.page, limit: pagination.limit }
      : null,
    sort,
  };
};

const buildPaginationMeta = (total, page, limit) => {
  const totalPages = limit > 0 ? Math.ceil(total / limit) : 0;
  return {
    total,
    page,
    limit,
    pages: totalPages,
  };
};

module.exports = {
  applyQueryOptions,
  buildPaginationMeta,
  parsePagination,
};
