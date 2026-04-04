// MongoDB initialization script.
// Creates collections and indexes for local demo runs.

db = db.getSiblingDB('agrilens');

db.createCollection('users');
db.users.createIndex({ phone: 1 }, { unique: true, name: 'idx_users_phone' });

db.createCollection('farms');
db.farms.createIndex({ owner_id: 1 }, { name: 'idx_farms_owner' });

db.createCollection('scans');
db.scans.createIndex({ user_id: 1 }, { name: 'idx_scans_user' });
db.scans.createIndex({ farm_id: 1 }, { name: 'idx_scans_farm' });
db.scans.createIndex({ field_id: 1 }, { name: 'idx_scans_field' });
db.scans.createIndex({ created_at: -1 }, { name: 'idx_scans_created' });
db.scans.createIndex({ status: 1 }, { name: 'idx_scans_status' });

db.createCollection('notifications');
db.notifications.createIndex(
  { user_id: 1, is_read: 1 },
  { name: 'idx_notifications_user_read' },
);
db.notifications.createIndex({ created_at: -1 }, { name: 'idx_notifications_created' });

db.createCollection('forecasts');
db.forecasts.createIndex({ user_id: 1 }, { name: 'idx_forecasts_user' });
db.forecasts.createIndex({ updated_at: -1 }, { name: 'idx_forecasts_updated' });

db.createCollection('audit_logs');
db.audit_logs.createIndex({ user_id: 1, timestamp: -1 }, { name: 'idx_audit_user_time' });
db.audit_logs.createIndex({ action: 1 }, { name: 'idx_audit_action' });

print('AgriLens collections and indexes created');
