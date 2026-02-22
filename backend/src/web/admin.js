const apiBase = window.location.origin;
const tokenKey = 'fa_admin_token';

const byId = (id) => document.getElementById(id);

const showMsg = (el, message, isError = false) => {
  if (!el) return;
  el.style.display = 'block';
  el.textContent = message;
  el.style.background = isError ? '#ffe3e3' : '#fde7ee';
  el.style.color = isError ? '#c62828' : '#e91e63';
};

const unwrapList = (data) => {
  if (Array.isArray(data)) return data;
  if (data && Array.isArray(data.data)) return data.data;
  return [];
};

const fetchJson = async (path, options = {}) => {
  const res = await fetch(`${apiBase}${path}`, options);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = data?.message || data?.error || `Request failed: ${res.status}`;
    throw new Error(message);
  }
  return data;
};

const fetchAuth = (path, token) =>
  fetchJson(path, {
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
  });

const setText = (id, value) => {
  const el = byId(id);
  if (el) el.textContent = value;
};

const setTable = (id, rowsHtml, emptyMessage) => {
  const table = byId(id);
  if (!table) return;
  table.innerHTML = rowsHtml || `<tr><td colspan="10">${emptyMessage}</td></tr>`;
};

const loadCounts = async (token) => {
  try {
    const [orders, users, florists, promotions, cities, categories] = await Promise.all([
      fetchAuth('/api/orders?page=1&limit=1', token),
      fetchAuth('/api/admin/users?role=user&page=1&limit=1', token),
      fetchAuth('/api/admin/users?role=florist&page=1&limit=1', token),
      fetchJson('/api/promotions?all=true'),
      fetchJson('/api/cities'),
      fetchJson('/api/categories'),
    ]);

    const ordersCount = orders?.pagination?.total ?? unwrapList(orders).length;
    const usersCount = users?.pagination?.total ?? unwrapList(users).length;
    const floristsCount = florists?.pagination?.total ?? unwrapList(florists).length;
    const promotionsCount = unwrapList(promotions).length;
    const citiesCount = unwrapList(cities).length;
    const categoriesCount = unwrapList(categories).length;

    setText('kpi-orders', ordersCount);
    setText('kpi-users', usersCount);
    setText('kpi-florists', floristsCount);
    setText('kpi-promotions', promotionsCount);

    setText('nav-orders-count', `(${ordersCount})`);
    setText('nav-users-count', `(${usersCount})`);
    setText('nav-florists-count', `(${floristsCount})`);
    setText('nav-promotions-count', `(${promotionsCount})`);
    setText('nav-cities-count', `(${citiesCount})`);
    setText('nav-categories-count', `(${categoriesCount})`);
  } catch (err) {
    showMsg(byId('login-msg'), err.message, true);
  }
};

const loadOverview = async (token) => {
  try {
    const orderList = await fetchAuth('/api/orders?page=1&limit=5&sort=-createdAt', token);
    const ordersData = unwrapList(orderList);
    setTable(
      'orders-table',
      ordersData
        .map((order) => {
          const florist = order.floristId?.shopName || order.floristId?.name || '—';
          return `
          <tr>
            <td>${order.orderNumber || order._id || '—'}</td>
            <td>${order.status || '—'}</td>
            <td>${florist}</td>
            <td>₸ ${Number(order.totalPrice || 0).toFixed(0)}</td>
          </tr>`;
        })
        .join(''),
      'No orders found.'
    );
  } catch (err) {
    setTable('orders-table', '', 'Failed to load orders.');
  }
};

const loadUsers = async (token) => {
  try {
    const data = await fetchAuth('/api/admin/users?role=user&limit=10&sort=-createdAt', token);
    const list = unwrapList(data);
    setTable(
      'users-table',
      list
        .map((user) => {
          return `
          <tr>
            <td>${user.name || '—'}</td>
            <td>${user.email || '—'}</td>
            <td>${user.city || '—'}</td>
            <td>${user.status || '—'}</td>
          </tr>`;
        })
        .join(''),
      'No users found.'
    );
  } catch (err) {
    setTable('users-table', '', 'Failed to load users.');
  }
};

const loadFlorists = async (token) => {
  try {
    const data = await fetchAuth('/api/admin/users?role=florist&limit=10&sort=-createdAt', token);
    const list = unwrapList(data);
    setTable(
      'florists-table',
      list
        .map((user) => {
          return `
          <tr>
            <td>${user.name || '—'}</td>
            <td>${user.shopName || '—'}</td>
            <td>${user.city || '—'}</td>
            <td>${user.status || '—'}</td>
          </tr>`;
        })
        .join(''),
      'No florists found.'
    );
  } catch (err) {
    setTable('florists-table', '', 'Failed to load florists.');
  }
};

const loadOrders = async (token) => {
  try {
    const data = await fetchAuth('/api/orders?limit=10&sort=-createdAt', token);
    const list = unwrapList(data);
    setTable(
      'all-orders-table',
      list
        .map((order) => {
          return `
          <tr>
            <td>${order.orderNumber || order._id || '—'}</td>
            <td>${order.status || '—'}</td>
            <td>${order.city || '—'}</td>
            <td>₸ ${Number(order.totalPrice || 0).toFixed(0)}</td>
          </tr>`;
        })
        .join(''),
      'No orders found.'
    );
  } catch (err) {
    setTable('all-orders-table', '', 'Failed to load orders.');
  }
};

const loadPromotions = async () => {
  try {
    const data = await fetchJson('/api/promotions?all=true');
    const list = unwrapList(data);
    setTable(
      'promotions-table',
      list
        .map((promo) => {
          return `
          <tr>
            <td>${promo.title || '—'}</td>
            <td>${promo.isActive ? 'Yes' : 'No'}</td>
            <td>${promo.sortOrder ?? 0}</td>
          </tr>`;
        })
        .join(''),
      'No promotions found.'
    );
  } catch (err) {
    setTable('promotions-table', '', 'Failed to load promotions.');
  }
};

const loadCities = async () => {
  try {
    const data = await fetchJson('/api/cities');
    const list = unwrapList(data);
    setTable(
      'cities-table',
      list
        .map((city) => `<tr><td>${city.name || '—'}</td></tr>`)
        .join(''),
      'No cities found.'
    );
  } catch (err) {
    setTable('cities-table', '', 'Failed to load cities.');
  }
};

const loadCategories = async () => {
  try {
    const data = await fetchJson('/api/categories');
    const list = unwrapList(data);
    setTable(
      'categories-table',
      list
        .map((category) => `<tr><td>${category.name || '—'}</td></tr>`)
        .join(''),
      'No categories found.'
    );
  } catch (err) {
    setTable('categories-table', '', 'Failed to load categories.');
  }
};

const showSection = (sectionName) => {
  const sections = [
    'overview',
    'users',
    'florists',
    'orders',
    'promotions',
    'cities',
    'categories',
  ];
  sections.forEach((name) => {
    const section = byId(`section-${name}`);
    if (section) {
      section.classList.toggle('hidden', name !== sectionName);
    }
  });

  document.querySelectorAll('.sidebar a').forEach((link) => {
    link.classList.toggle('active', link.dataset.section === sectionName);
  });
};

const loadSectionData = async (section, token) => {
  if (!token) {
    showMsg(byId('login-msg'), 'Login required to view this data.', true);
    return;
  }
  if (section === 'overview') {
    await loadOverview(token);
  } else if (section === 'users') {
    await loadUsers(token);
  } else if (section === 'florists') {
    await loadFlorists(token);
  } else if (section === 'orders') {
    await loadOrders(token);
  } else if (section === 'promotions') {
    await loadPromotions();
  } else if (section === 'cities') {
    await loadCities();
  } else if (section === 'categories') {
    await loadCategories();
  }
};

const init = () => {
  const stored = localStorage.getItem(tokenKey);
  if (stored) {
    const logoutBtn = byId('logout-btn');
    if (logoutBtn) logoutBtn.classList.remove('hidden');
    loadCounts(stored);
    loadOverview(stored);
  } else {
    const logoutBtn = byId('logout-btn');
    if (logoutBtn) logoutBtn.classList.add('hidden');
    setTable('orders-table', '', 'Login required to view orders.');
    setTable('users-table', '', 'Login required to view users.');
    setTable('florists-table', '', 'Login required to view florists.');
    setTable('all-orders-table', '', 'Login required to view orders.');
    setTable('promotions-table', '', 'Login required to view promotions.');
    setTable('cities-table', '', 'Login required to view cities.');
    setTable('categories-table', '', 'Login required to view categories.');
  }

  document.querySelectorAll('.sidebar a').forEach((link) => {
    link.addEventListener('click', async (event) => {
      event.preventDefault();
      const section = link.dataset.section;
      showSection(section);
      const token = localStorage.getItem(tokenKey);
      await loadSectionData(section, token);
    });
  });

  const loginForm = byId('login-form');
  loginForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const email = byId('login-email').value.trim();
    const password = byId('login-password').value;

    try {
      const data = await fetchJson('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const token = data?.token || data?.data?.token;
      if (!token) {
        throw new Error('Token not returned by server');
      }
      localStorage.setItem(tokenKey, token);
      showMsg(byId('login-msg'), 'Login successful. Loading data...');
      const logoutBtn = byId('logout-btn');
      if (logoutBtn) logoutBtn.classList.remove('hidden');
      await loadCounts(token);
      await loadOverview(token);
      showSection('overview');
    } catch (err) {
      showMsg(byId('login-msg'), err.message, true);
    }
  });

  const logoutBtn = byId('logout-btn');
  logoutBtn?.addEventListener('click', () => {
    localStorage.removeItem(tokenKey);
    if (logoutBtn) logoutBtn.classList.add('hidden');
    showMsg(byId('login-msg'), 'Logged out.', false);
    setTable('orders-table', '', 'Login required to view orders.');
    setTable('users-table', '', 'Login required to view users.');
    setTable('florists-table', '', 'Login required to view florists.');
    setTable('all-orders-table', '', 'Login required to view orders.');
    setTable('promotions-table', '', 'Login required to view promotions.');
    setTable('cities-table', '', 'Login required to view cities.');
    setTable('categories-table', '', 'Login required to view categories.');
    showSection('overview');
  });
};

init();
