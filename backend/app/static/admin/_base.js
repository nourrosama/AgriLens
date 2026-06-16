// Shared helpers for all admin pages
const API = '';

function getToken() {
  const t = localStorage.getItem('admin_token');
  if (!t) { window.location.href = '/admin/login.html'; return null; }
  return t;
}

function getUser() {
  try { return JSON.parse(localStorage.getItem('admin_user') || '{}'); } catch { return {}; }
}

function logout() {
  localStorage.removeItem('admin_token');
  localStorage.removeItem('admin_user');
  window.location.href = '/admin/login.html';
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

// Render sidebar active state
document.addEventListener('DOMContentLoaded', () => {
  const path = window.location.pathname.split('/').pop();
  document.querySelectorAll('.nav-link').forEach(a => {
    if (a.getAttribute('href') === path) a.classList.add('active');
  });
  const u = getUser();
  const el = document.getElementById('admin-name');
  if (el) el.textContent = u.name || 'Admin';
});
