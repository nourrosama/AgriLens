/* ── AgriLens User Portal — Base JS ───────────────────────────────────────── */
'use strict';

const API = '';   // same origin

/* ── Auth helpers ──────────────────────────────────────────────────────────── */
const Auth = {
  token:      () => localStorage.getItem('agrilens_token'),
  user:       () => JSON.parse(localStorage.getItem('agrilens_user') || 'null'),
  plan:       () => Auth.user()?.plan || 'free',
  save:       (token, user) => {
    localStorage.setItem('agrilens_token', token);
    localStorage.setItem('agrilens_user', JSON.stringify(user));
  },
  clear:      () => {
    localStorage.removeItem('agrilens_token');
    localStorage.removeItem('agrilens_user');
  },
  isLoggedIn: () => !!Auth.token(),
  requireLogin: () => { if (!Auth.isLoggedIn()) window.location.href = '/app/login'; },
};

/* ── API fetch wrapper ─────────────────────────────────────────────────────── */
// BUG FIX: spread options.headers AFTER the default Authorization so explicit
// headers (e.g. a freshly obtained token passed before Auth.save()) are not
// overwritten by the stale token sitting in localStorage.
async function apiFetch(path, options = {}) {
  const token   = Auth.token();
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...(options.headers || {}),   // caller wins — never overwrite explicit header
  };

  if (options.body instanceof FormData) delete headers['Content-Type'];

  const res  = await fetch(API + path, { ...options, headers });
  const data = await res.json().catch(() => ({}));

  if (res.status === 401) {
    Auth.clear();
    window.location.href = '/app/login';
    return;
  }
  return { ok: res.ok, status: res.status, data };
}

/* ── Server-side plan verification ────────────────────────────────────────── */
// Call once per page load. Fetches the real plan from /api/subscription/status,
// updates localStorage so every planMeets() call reflects the DB truth.
let _planVerified = false;
async function syncPlanFromServer() {
  if (_planVerified) return Auth.plan();
  const res = await apiFetch('/api/subscription/status');
  if (res?.ok) {
    const serverPlan = res.data.data?.plan;
    if (serverPlan) {
      const user = Auth.user();
      if (user && user.plan !== serverPlan) {
        user.plan = serverPlan;
        Auth.save(Auth.token(), user);
      }
    }
  }
  _planVerified = true;
  return Auth.plan();
}

/* ── Toast ─────────────────────────────────────────────────────────────────── */
function toast(message, type = 'default', duration = 3500) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = message;
  container.appendChild(el);
  setTimeout(() => {
    el.style.opacity = '0';
    el.style.transform = 'translateX(100%)';
    el.style.transition = 'all .3s';
    setTimeout(() => el.remove(), 300);
  }, duration);
}

/* ── Plan utilities ────────────────────────────────────────────────────────── */
const PLAN_RANK  = { free: 0, premium: 1, professional: 2 };
const PLAN_LABEL = { free: 'Free', premium: 'Premium', professional: 'Professional' };

function planMeets(required) {
  return (PLAN_RANK[Auth.plan()] || 0) >= (PLAN_RANK[required] || 0);
}

function renderPlanBadge(plan) {
  return `<span class="plan-badge ${plan}">${PLAN_LABEL[plan] || plan}</span>`;
}

function gateHtml(requiredPlan, featureLabel) {
  const features = {
    premium:      ['Unlimited scans', 'AI disease report', 'Severity assessment',
                   'Symptoms & causes', 'Treatment plan', 'Recovery timeline',
                   'Preventive measures', 'AI Chatbot', 'Weather risk'],
    professional: ['PDF report export', 'Farm dashboard', 'Disease history tracking',
                   'Trend analytics', 'Yield impact estimation', 'Cost estimation',
                   'Farm-wide insights'],
  };
  const featureList = (features[requiredPlan] || [])
    .map(f => `<span class="gate-feature">✓ ${f}</span>`).join('');
  return `
    <div class="gate-overlay">
      <div class="gate-icon">🔒</div>
      <h3>${featureLabel} — ${PLAN_LABEL[requiredPlan]} Plan Required</h3>
      <p>Upgrade your plan to unlock this feature and many more tools for your farm.</p>
      <div class="gate-features">${featureList}</div>
      <button class="btn btn-amber btn-lg" onclick="openUpgradeModal('${requiredPlan}')">
        ⬆ Upgrade to ${PLAN_LABEL[requiredPlan]}
      </button>
    </div>`;
}

/* ── Sidebar bootstrap ─────────────────────────────────────────────────────── */
function initSidebar(activePage) {
  const user = Auth.user();
  if (!user) return;

  const planNow = user.plan || 'free';

  // User info
  const nameEl   = document.getElementById('sb-name');
  const emailEl  = document.getElementById('sb-email');
  const avatarEl = document.getElementById('sb-avatar');
  if (nameEl)   nameEl.textContent   = user.name  || 'Farmer';
  if (emailEl)  emailEl.textContent  = user.phone  || user.email || '';
  if (avatarEl) avatarEl.textContent = (user.name || 'F')[0].toUpperCase();

  // Plan badge
  const planBadge = document.getElementById('sb-plan-badge');
  if (planBadge) {
    planBadge.className   = `plan-badge ${planNow}`;
    planBadge.textContent = PLAN_LABEL[planNow] || 'Free';
  }

  // Hide upgrade CTA for professional
  const cta = document.getElementById('sb-upgrade-cta');
  if (cta && planNow === 'professional') cta.style.display = 'none';

  // Active nav + lock locked items that don't meet the plan
  document.querySelectorAll('.nav-item').forEach(el => {
    if (el.dataset.page === activePage) el.classList.add('active');
    const lockEl = el.querySelector('.lock-icon');
    if (lockEl) {
      // Dim and disable nav items the user cannot access
      el.classList.add('locked');
      el.addEventListener('click', e => {
        e.preventDefault();
        const requiredPlan = el.dataset.page === 'chatbot' ? 'premium' : 'professional';
        toast(`This feature requires the ${PLAN_LABEL[requiredPlan]} plan. Upgrade to unlock.`, 'error');
        openUpgradeModal(requiredPlan);
      });
    }
  });

  // Hamburger
  const burger  = document.getElementById('hamburger');
  const sidebar = document.getElementById('sidebar');
  if (burger && sidebar) {
    burger.addEventListener('click', () => sidebar.classList.toggle('open'));
    document.addEventListener('click', e => {
      if (!sidebar.contains(e.target) && !burger.contains(e.target))
        sidebar.classList.remove('open');
    });
  }

  // Logout
  document.getElementById('btn-logout')?.addEventListener('click', () => {
    Auth.clear();
    window.location.href = '/app/login';
  });
}

/* ── Upgrade modal ─────────────────────────────────────────────────────────── */
function openUpgradeModal(targetPlan) {
  const existing = document.getElementById('upgrade-modal');
  if (existing) existing.remove();

  const modal = document.createElement('div');
  modal.id = 'upgrade-modal';
  modal.className = 'modal-backdrop';
  modal.innerHTML = `
    <div class="modal">
      <button class="modal-close" onclick="document.getElementById('upgrade-modal').remove()">✕</button>
      <div class="modal-title">Upgrade Your Plan</div>
      <p style="color:var(--grey-500);font-size:14px;margin-bottom:20px;">
        Select the plan that fits your farm's needs.
      </p>
      <div id="upgrade-plans" style="display:flex;flex-direction:column;gap:12px;"></div>
      <div id="upgrade-msg" style="margin-top:14px;"></div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', e => { if (e.target === modal) modal.remove(); });

  const allPlans = [
    { id: 'premium',      label: '⭐ Premium',      price: '$19/month', color: 'amber',
      desc: 'Unlimited scans · AI reports · Chatbot · Weather risk' },
    { id: 'professional', label: '👑 Professional', price: '$49/month', color: 'purple',
      desc: 'Everything + PDF export · Farm dashboard · Analytics' },
  ];
  const plans = targetPlan === 'premium' ? allPlans : allPlans.filter(p => p.id === 'professional');

  const container = document.getElementById('upgrade-plans');
  plans.forEach(p => {
    const div = document.createElement('div');
    div.style.cssText = 'border:1.5px solid var(--grey-200);border-radius:10px;padding:14px 18px;cursor:pointer;transition:all .2s;';
    div.innerHTML = `<div style="display:flex;justify-content:space-between;align-items:center;">
      <div>
        <div style="font-weight:700;font-size:15px;">${p.label}</div>
        <div style="font-size:12px;color:var(--grey-500);margin-top:2px;">${p.desc}</div>
      </div>
      <div style="font-weight:800;font-size:15px;color:var(--green-700);">${p.price}</div>
    </div>`;
    div.addEventListener('mouseenter', () => div.style.borderColor = 'var(--green-600)');
    div.addEventListener('mouseleave', () => div.style.borderColor = 'var(--grey-200)');
    div.addEventListener('click', () => upgradePlan(p.id));
    container.appendChild(div);
  });
}

async function upgradePlan(plan) {
  const msgEl = document.getElementById('upgrade-msg');
  if (msgEl) msgEl.innerHTML = '<div style="color:var(--grey-500);font-size:13px;">Processing…</div>';
  const res = await apiFetch('/api/subscription/upgrade', {
    method: 'POST',
    body: JSON.stringify({ plan }),
  });
  if (res?.ok) {
    const user = Auth.user();
    user.plan = plan;
    Auth.save(Auth.token(), user);
    if (msgEl) msgEl.innerHTML = '<div class="alert alert-success">✅ Plan upgraded! Refreshing…</div>';
    setTimeout(() => window.location.reload(), 1200);
  } else {
    const msg = res?.data?.message || 'Upgrade failed.';
    if (msgEl) msgEl.innerHTML = `<div class="alert alert-error">❌ ${msg}</div>`;
  }
}

/* ── Quota bar renderer ────────────────────────────────────────────────────── */
function renderQuotaBar(quota) {
  if (!quota || quota.unlimited) return '<span class="badge badge-green">Unlimited scans ✓</span>';
  const pct    = Math.min(100, Math.round((quota.used / quota.limit) * 100));
  const danger = pct >= 80;
  return `
    <div class="quota-bar-wrap">
      <div class="quota-bar-track">
        <div class="quota-bar-fill${danger ? ' danger' : ''}" style="width:${pct}%"></div>
      </div>
      <div class="quota-text">${quota.used} / ${quota.limit} scans used this month
        ${danger ? ' — <a href="#" onclick="openUpgradeModal(\'premium\')">Upgrade for unlimited</a>' : ''}
      </div>
    </div>`;
}

/* ── Severity badge ────────────────────────────────────────────────────────── */
function severityBadge(sev) {
  const map = { none:'badge-green', low:'badge-green', medium:'badge-amber', high:'badge-red', unknown:'badge-grey' };
  return `<span class="badge ${map[sev] || 'badge-grey'}">${(sev || 'unknown').toUpperCase()}</span>`;
}

/* ── Format date ───────────────────────────────────────────────────────────── */
function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, { year:'numeric', month:'short', day:'numeric' });
}
