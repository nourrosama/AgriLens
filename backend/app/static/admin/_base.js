// Shared helpers for all admin pages
const API = '';

function getToken() {
  const t = localStorage.getItem('admin_token');
  if (!t) { window.location.href = '/#/login'; return null; }
  return t;
}

function getUser() {
  try { return JSON.parse(localStorage.getItem('admin_user') || '{}'); } catch { return {}; }
}

function logout() {
  localStorage.removeItem('admin_token');
  localStorage.removeItem('admin_user');
  // Mobile WebView: Flutter injected _flutterAdminLogout — call it so the
  // native side can run userProvider.logout() and navigate to /login.
  if (typeof window._flutterAdminLogout === 'function') {
    window._flutterAdminLogout();
    return;
  }
  // Flutter Web: this page is inside a cross-origin <iframe>.
  // postMessage to the parent Flutter app — it will navigate to /login.
  if (window.self !== window.top) {
    window.parent.postMessage({ type: 'agrilens_logout' }, '*');
    return;
  }
  // Standalone browser (not embedded in the app).
  window.location.replace('/#/login');
}

async function apiFetch(path, options = {}) {
  const token = getToken();
  if (!token) return null;
  const res = await fetch(API + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
  if (res.status === 401 || res.status === 403) { logout(); return null; }
  return res;
}

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtDatetime(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function badge(text, color) {
  const colors = { green: '#e8f5e9;color:#2e7d32', red: '#ffebee;color:#c62828', orange: '#fff3e0;color:#e65100', blue: '#e3f2fd;color:#1565c0', grey: '#f5f5f5;color:#555' };
  const style = colors[color] || colors.grey;
  return `<span style="padding:2px 10px;border-radius:12px;font-size:12px;font-weight:600;background:${style.split(';')[0].replace('background:','')};${style.split(';')[1]}">${text}</span>`;
}

// Render sidebar active state + inject topbar user chip
document.addEventListener('DOMContentLoaded', () => {
  // Active nav link
  const path = window.location.pathname.split('/').pop();
  document.querySelectorAll('.nav-link').forEach(a => {
    if (a.getAttribute('href') === path) a.classList.add('active');
  });

  const u = getUser();
  const name = u.name || 'Admin';
  const initial = name.charAt(0).toUpperCase();

  // Inject user chip + logout into the topbar
  const topbar = document.querySelector('.topbar');
  if (topbar) {
    // Preserve existing title text
    const titleText = topbar.textContent.trim();
    topbar.innerHTML = `
      <span class="topbar-title">${titleText}</span>
      <div class="topbar-right">
        <div class="topbar-avatar">${initial}</div>
        <span class="topbar-name">${name}</span>
        <button class="logout-btn" onclick="logout()">Logout</button>
      </div>
    `;
  }

  // Legacy: also populate any standalone #admin-name element
  const el = document.getElementById('admin-name');
  if (el) el.textContent = name;
});
