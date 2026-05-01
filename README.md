# TalkEncrypted

A private, invite-only messaging API. Users can only join with an invite code. No passwords — authentication is done via email OTP. Messages are encrypted at rest.

Built with Ruby on Rails 8, PostgreSQL, Action Cable for real-time events, and Solid Queue for background jobs.

---

## Running with Docker (Recommended)

This is the easiest way to run the app locally. You only need **Docker Desktop** installed — no Ruby, no PostgreSQL, nothing else.

### 1. Install Docker Desktop

Download and install from [docker.com](https://www.docker.com/products/docker-desktop). Open it and let it start before continuing.

### 2. Clone the repo

```bash
git clone https://github.com/talkencrypted-maker/talkEncrypted.git
cd talkEncrypted
```

### 3. Create a `.env` file

Create a file called `.env` in the project root with the master key (get this from the project owner):

```
RAILS_MASTER_KEY=your_master_key_here
```

### 4. Start everything

```bash
docker-compose up
```

This will:
- Start a PostgreSQL database
- Create the database and run all migrations automatically
- Start the Solid Queue background job worker
- Start the Rails server

The API will be available at `http://localhost:3000/api`.

### 5. Stop everything

```bash
docker-compose down
```

To also delete the database volume (wipe all data):

```bash
docker-compose down -v
```

---

## Running Locally (Without Docker)

If you prefer to run without Docker, you will need:

- Ruby 4.0.3
- PostgreSQL 14+
- Bundler

### 1. Install dependencies

```bash
bundle install
```

### 2. Set up the database

```bash
bin/rails db:create db:migrate
```

### 3. Set up Solid Queue tables

```bash
bin/rails runner "load Rails.root.join('db/queue_schema.rb')"
```

### 4. Start the Rails server

```bash
bin/rails server
```

### 5. Start the Solid Queue worker (separate terminal)

```bash
bin/rails solid_queue:start
```

The API will be available at `http://localhost:3000/api`.

---

## API Overview

All endpoints (except auth) require:

```
Authorization: Bearer <token>
Content-Type: application/json
```

| Method | URL | Description |
|--------|-----|-------------|
| POST | `/api/auth/otp/request` | Request OTP (invite code required for new users) |
| POST | `/api/auth/otp/verify` | Verify OTP and get Bearer token |
| DELETE | `/api/logout` | End session |
| GET | `/api/me` | Get my profile |
| PATCH | `/api/me` | Update display name / bio |
| GET | `/api/users/search` | Search for users |
| GET | `/api/conversations` | List my conversations |
| POST | `/api/conversations` | Start a new conversation |
| GET | `/api/conversations/:id` | Get conversation details |
| POST | `/api/conversations/:id/read` | Mark conversation as read |
| GET | `/api/conversations/:id/messages` | Load messages |
| POST | `/api/conversations/:id/messages` | Send a message |

### WebSocket

Connect with your Bearer token:

```
ws://localhost:3000/cable?token=<your_token>
```

Subscribe to a conversation:

```json
{ "channel": "ConversationChannel", "conversation_id": 5 }
```

Real-time events you will receive:

| Event type | When it fires |
|-----------|---------------|
| `message.created` | A new message is sent |
| `conversation.read` | Someone marks the conversation as read |
| `link_preview.updated` | A link preview finishes loading |

---

## Security

- Message bodies are **encrypted at rest** using Rails Active Record Encryption
- Session tokens are stored as SHA-256 digests — raw tokens are never saved
- OTP codes are stored as SHA-256 digests — raw codes are never saved
- Invite codes are stored as SHA-256 digests — raw codes are never saved
- WebSocket connections are authenticated via Bearer token
