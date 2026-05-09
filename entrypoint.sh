#!/bin/bash
set -e

# Remove stale puma server pid if it exists from a previous run
rm -f /app/tmp/pids/server.pid

# Wait for PostgreSQL to be ready before doing anything
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${DB_HOST:-$PGHOST}" -U "${DB_USER:-$PGUSER}" -q; do
  sleep 1
done
echo "PostgreSQL is ready."

# Create the database if it doesn't exist, then run any pending migrations
echo "Running db:prepare..."
bin/rails db:prepare
echo "db:prepare completed successfully."

# Load Solid Queue tables if they don't exist yet
echo "Checking Solid Queue tables..."
bin/rails runner "
begin
  SolidQueue::Job.count
  puts 'Solid Queue tables already exist, skipping.'
rescue ActiveRecord::StatementInvalid
  puts 'Creating Solid Queue tables...'
  load Rails.root.join('db/queue_schema.rb')
  puts 'Solid Queue tables created.'
end
"
echo "Solid Queue check completed."

echo "Checking Solid Cache tables..."
bin/rails runner "
begin
  SolidCache::Entry.count
  puts 'Solid Cache tables already exist, skipping.'
rescue ActiveRecord::StatementInvalid
  puts 'Creating Solid Cache tables...'
  load Rails.root.join('db/cache_schema.rb')
  puts 'Solid Cache tables created.'
end
"
echo "Solid Cache check completed."

echo "Checking Solid Cable tables..."
bin/rails runner "
conn = SolidCable::Record.connection
begin
  conn.execute('SELECT COUNT(*) FROM solid_cable_messages')
  puts 'Solid Cable tables already exist, skipping.'
rescue ActiveRecord::StatementInvalid
  puts 'Creating Solid Cable tables...'
  conn.create_table :solid_cable_messages, force: :cascade do |t|
    t.binary :channel, limit: 1024, null: false
    t.binary :payload, limit: 536870912, null: false
    t.datetime :created_at, null: false
    t.integer :channel_hash, limit: 8, null: false
    t.index :channel, name: 'index_solid_cable_messages_on_channel'
    t.index :channel_hash, name: 'index_solid_cable_messages_on_channel_hash'
    t.index :created_at, name: 'index_solid_cable_messages_on_created_at'
  end
  puts 'Solid Cable tables created.'
end
"
echo "Solid Cable check completed."

echo "Starting Rails server on port ${PORT:-3000}..."
# Hand off to the main process (rails server or solid_queue:start)
exec "$@"
