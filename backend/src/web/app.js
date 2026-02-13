const apiBase = window.location.origin;

const byId = (id) => document.getElementById(id);

const unwrapList = (data) => {
  if (Array.isArray(data)) return data;
  if (data && Array.isArray(data.data)) return data.data;
  return [];
};

const fetchJson = async (path) => {
  const res = await fetch(`${apiBase}${path}`);
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`);
  }
  return res.json();
};

const setCount = (id, value) => {
  const el = byId(id);
  if (el) el.textContent = value;
};

const loadCounts = async () => {
  try {
    const [flowers, categories, cities] = await Promise.all([
      fetchJson('/api/flowers?page=1&limit=1'),
      fetchJson('/api/categories'),
      fetchJson('/api/cities'),
    ]);

    const flowerCount = flowers?.pagination?.total ?? unwrapList(flowers).length;
    setCount('stat-flowers', flowerCount);
    setCount('stat-categories', unwrapList(categories).length);
    setCount('stat-cities', unwrapList(cities).length);
  } catch (err) {
    setCount('stat-flowers', '—');
    setCount('stat-categories', '—');
    setCount('stat-cities', '—');
  }
};

const loadFlowers = async () => {
  const grid = byId('flower-grid');
  if (!grid) return;

  try {
    const data = await fetchJson('/api/flowers?limit=6&page=1');
    const list = unwrapList(data);
    if (list.length === 0) {
      grid.innerHTML = '<div class="card">No flowers found.</div>';
      return;
    }

    grid.innerHTML = list
      .map((flower) => {
        const imageUrl = flower.image_url || flower.imageUrl || 'assets/placeholder.jpg';
        const name = flower.name || 'Flower';
        const price = flower.price || 0;
        const city = flower.city || 'Unknown city';
        return `
        <div class="product">
          <img src="${imageUrl}" alt="${name}" />
          <div class="content">
            <div style="display:flex;justify-content:space-between;align-items:center;">
              <strong>${name}</strong>
              <span class="badge">₸ ${Number(price).toFixed(0)}</span>
            </div>
            <div style="margin-top:6px;color:#6b6b6b;font-size:13px;">${city}</div>
          </div>
        </div>`;
      })
      .join('');
  } catch (err) {
    grid.innerHTML = '<div class="card">Failed to load flowers.</div>';
  }
};

loadCounts();
loadFlowers();
