// MongoDB initialization script — run once on first container start.
// Creates collections and indexes for performance & data integrity.

db = db.getSiblingDB('agrilens');

// ── Users ────────────────────────────────────────────────────
db.createCollection('users');
db.users.createIndex({ "phone": 1 }, { unique: true, name: "idx_users_phone" });

// ── Farms ────────────────────────────────────────────────────
db.createCollection('farms');
db.farms.createIndex({ "owner_id": 1 }, { name: "idx_farms_owner" });

// ── Scans ────────────────────────────────────────────────────
db.createCollection('scans');
db.scans.createIndex({ "user_id": 1 },     { name: "idx_scans_user" });
db.scans.createIndex({ "farm_id": 1 },     { name: "idx_scans_farm" });
db.scans.createIndex({ "created_at": -1 }, { name: "idx_scans_created" });
db.scans.createIndex({ "status": 1 },      { name: "idx_scans_status" });

// ── Audit Logs ───────────────────────────────────────────────
db.createCollection('audit_logs');
db.audit_logs.createIndex({ "user_id": 1, "timestamp": -1 }, { name: "idx_audit_user_time" });
db.audit_logs.createIndex({ "action": 1 },                   { name: "idx_audit_action" });

print('✅ AgriLens collections and indexes created');
