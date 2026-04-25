# Talk Encrypted Backend Guide

This project is a Ruby on Rails API backend for a chat MVP. The current backend stack is:

- Ruby 4.0.3
- Rails 8.1.3 API mode
- PostgreSQL 17
- Solid Queue for background jobs
- Solid Cable for realtime/WebSocket infrastructure
- Solid Cache for database-backed caching

Docker is intentionally not part of the local setup right now.

## One-Time Shell Setup

Homebrew Ruby and PostgreSQL are installed, but macOS may still pick its older system Ruby unless this path is loaded first.

Add this to your shell config, usually `~/.zshrc`:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:/opt/homebrew/opt/postgresql@17/bin:$PATH"
```

Then restart the terminal or run:

```bash
source ~/.zshrc
```

Check versions:

```bash
ruby --version
rails --version
psql --version
```

## Daily Commands

Start PostgreSQL:

```bash
brew services start postgresql@17
```

Stop PostgreSQL:

```bash
brew services stop postgresql@17
```

Check PostgreSQL service status:

```bash
brew services list
```

Install Ruby gems after pulling changes:

```bash
bundle install
```

Create databases:

```bash
bin/rails db:create
```

Run database migrations:

```bash
bin/rails db:migrate
```

Reset the local database:

```bash
bin/rails db:reset
```

Start the Rails API server:

```bash
bin/rails server
```

Open the Rails console:

```bash
bin/rails console
```

List API routes:

```bash
bin/rails routes
```

Run tests:

```bash
bin/rails test
```

Run the full Rails CI script:

```bash
bin/ci
```

Run the background job worker:

```bash
bin/jobs
```

Run security checks:

```bash
bin/brakeman
bin/bundler-audit
```

Run Ruby style checks:

```bash
bin/rubocop
```

## Database Connection

Use these settings in DBeaver, TablePlus, Postico, or another PostgreSQL GUI:

```text
Host: localhost
Port: 5432
Database: talk_encrypted_development
User: viveklokhande
Password: blank
```

You can also connect from the terminal:

```bash
psql talk_encrypted_development
```

## Project Structure

The Rails app is organized around a few important folders.

`app/controllers`

This is where HTTP API endpoints live. For example, future endpoints like `POST /api/login` or `GET /api/conversations` will be handled by controller classes here.

`app/models`

This is where database-backed business objects live. Future chat models like `User`, `Conversation`, `ConversationMember`, `Message`, and `Link` will go here.

`app/jobs`

This is where background jobs live. Jobs are useful for work that should happen after an API response, such as extracting links from a message, fetching link preview data, sending notifications, or cleaning up old sessions.

`app/mailers`

This is where email-sending classes live. It is not central to the chat MVP yet, but it can be used later for login emails, password resets, or account notifications.

`config/routes.rb`

This file maps URLs to controllers. Example future routes:

```ruby
post "/api/login", to: "api/sessions#create"
get "/api/conversations", to: "api/conversations#index"
post "/api/conversations/:conversation_id/messages", to: "api/messages#create"
```

`config/database.yml`

This file tells Rails how to connect to PostgreSQL in development, test, and production.

`config/cable.yml`

This file configures Action Cable. Action Cable is Rails' WebSocket/realtime layer. In production, this project is set up to use Solid Cable instead of Redis.

`config/queue.yml`

This file configures Solid Queue. Solid Queue stores background jobs in PostgreSQL instead of Redis.

`config/cache.yml`

This file configures Solid Cache. Solid Cache stores cache data in PostgreSQL instead of Redis or memory.

`db/schema.rb`

This is the current database shape generated from migrations. Do not edit it manually. Change the database by creating and running migrations.

`db/*_schema.rb`

These are schemas for Rails' Solid systems:

- `db/queue_schema.rb` for Solid Queue
- `db/cable_schema.rb` for Solid Cable
- `db/cache_schema.rb` for Solid Cache

`test`

This is where automated tests live.

`bin`

This folder contains project-specific command wrappers. Prefer `bin/rails`, `bin/rake`, `bin/jobs`, and similar commands over global commands because they use this app's bundled dependencies.

## Important Files

`.ruby-version`

Declares the Ruby version for this project.

`Gemfile`

Lists Ruby dependencies.

`Gemfile.lock`

Locks exact dependency versions. Commit this file.

`.gitignore`

Keeps secrets, logs, temp files, and local storage out of Git.

`config/credentials.yml.enc`

Encrypted Rails credentials. This can be committed.

`config/master.key`

The key used to decrypt Rails credentials. This must not be committed.

## MVP Backend Shape

The planned chat MVP will likely add these models:

- `User`
- `Session`
- `Conversation`
- `ConversationMember`
- `Message`
- `Link`

The first API surface will likely include:

```text
POST   /api/signup
POST   /api/login
DELETE /api/logout
GET    /api/me
GET    /api/conversations
POST   /api/conversations
GET    /api/conversations/:id/messages
POST   /api/conversations/:id/messages
```

## Mental Model

PostgreSQL stores the durable data: users, conversations, messages, and links.

Solid Queue stores background job work in PostgreSQL, such as "extract links from message 123 later."

Solid Cable lets Rails do realtime chat events without Redis in production.

The Flutter app will eventually call JSON APIs and listen to realtime events. It does not need to know whether the backend uses Redis, Solid Queue, or Solid Cable internally.
