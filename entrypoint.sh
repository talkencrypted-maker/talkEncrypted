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
bin/rails db:prepare

# Load Solid Queue tables if they don't exist yet
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

# Hand off to the main process (rails server or solid_queue:start)
sleep 2
exec "$@"
