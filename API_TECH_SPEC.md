# Chat MVP API Tech Spec

This document describes the planned backend API for the text-and-link chat MVP.

The backend is a Rails API backed by PostgreSQL. It uses:

- Email OTP authentication
- Invite-code-gated first signup
- Opaque bearer tokens for authenticated API requests
- 1:1 conversations only
- Text messages only
- Link extraction and async link preview fetching through Solid Queue
- Realtime events through Action Cable and Solid Cable

## Product Flows

### First Signup

New users must have a personal invite code.

1. User enters email and invite code.
2. Backend validates that the invite code exists, is unused, and is not expired.
3. Backend creates an OTP for that email.
4. In development, Rails logs the OTP instead of sending a real email.
5. User submits the OTP.
6. Backend creates the user, consumes the invite code, and creates a session.
7. If the user has no display name, API returns `profile_required: true`.
8. User completes profile with `PATCH /api/me`.

Invite codes are consumed only after OTP verification succeeds. This prevents a bad actor from burning an invite code with an email address they cannot verify.

### Returning Login

Existing users do not need invite codes.

1. User enters email.
2. Backend creates an OTP for that email.
3. In development, Rails logs the OTP instead of sending a real email.
4. User submits the OTP.
5. Backend creates a new session and returns a bearer token.

### Starting A Chat

1. User searches for another user.
2. User selects a result.
3. Client calls `POST /api/conversations` with `recipient_id` to create or find the direct conversation.
4. Backend creates a direct conversation, or returns the existing direct conversation if one already exists.

### Sending A Message

1. User sends text.
2. Backend stores the message.
3. Backend extracts links from the message body.
4. Backend creates `message_links` rows with `status: "pending"`.
5. Backend enqueues a Solid Queue job to fetch link preview metadata.
6. Message send succeeds even if preview fetching later fails.

## Database Schemas

### users

```text
id
email
display_name
bio
profile_completed_at
created_at
updated_at
```

Rules:

- `email` is required.
- `email` is unique.
- `display_name` is required only after profile completion.
- `bio` is optional.
- `profile_completed_at` is set when the user submits a valid display name.

### invite_codes

```text
id
code_digest
label
used_by_user_id
used_at
expires_at
created_at
updated_at
```

Rules:

- Invite codes are single-use.
- Store only `code_digest`, not the raw invite code.
- `used_at` is set after successful OTP verification for a new user.
- `used_by_user_id` points to the created user.
- Expired invite codes cannot be used.

### email_otps

```text
id
email
invite_code_id
code_digest
purpose
expires_at
consumed_at
attempt_count
created_at
updated_at
```

Rules:

- Store only `code_digest`, not the raw OTP.
- OTPs expire after 10 minutes.
- `invite_code_id` is present for new-user signup OTPs.
- `invite_code_id` is blank for returning-user login OTPs.
- OTP is consumed after successful verification.
- `attempt_count` tracks failed verification attempts.

### user_sessions

```text
id
user_id
token_digest
last_used_at
expires_at
created_at
updated_at
```

Rules:

- Store only `token_digest`, not the raw bearer token.
- Raw token is returned once from OTP verification.
- Sessions expire after 30 days.
- Authenticated requests use `Authorization: Bearer <token>`.

### conversations

```text
id
kind
created_at
updated_at
```

Rules:

- MVP supports only `kind: "direct"`.
- Group chat is intentionally out of scope for MVP.

### conversation_members

```text
id
conversation_id
user_id
last_read_message_id
created_at
updated_at
```

Rules:

- Direct conversations must have exactly two members.
- A user cannot be added twice to the same conversation.
- `last_read_message_id` tracks read state.
- This table is internal; 1:1 API responses expose the other user as `recipient`.

### messages

```text
id
conversation_id
sender_id
body
created_at
updated_at
```

Rules:

- `body` is required.
- Message body stores text exactly as sent.
- Messages cannot be edited after they are sent.
- Messages cannot be deleted after they are sent.

### message_links

```text
id
message_id
url
domain
title
description
status
fetched_at
created_at
updated_at
```

Rules:

- Links are extracted from message body.
- `status` can be `pending`, `fetched`, or `failed`.
- `title` and `description` can be `null` while pending or failed.
- Preview fetching is best-effort and must not fail message creation.

## Recommended Indexes

```text
users.email unique
invite_codes.code_digest unique
invite_codes.used_by_user_id
email_otps.email
email_otps.invite_code_id
user_sessions.token_digest
conversation_members.user_id
conversation_members.conversation_id, user_id unique
messages.conversation_id, created_at
message_links.message_id
```

## Auth

Authenticated endpoints require:

```text
Authorization: Bearer <token>
```

Unauthenticated or expired sessions return:

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication is required."
  }
}
```

## Common Error Format

All API errors should use:

```json
{
  "error": {
    "code": "invalid_request",
    "message": "Human readable error message"
  }
}
```

Common status codes:

```text
400 bad request
401 unauthorized
403 forbidden
404 not found
422 validation failed
429 rate limited
```

## Endpoint Contracts

### POST /api/auth/otp/request

Request an OTP for signup or login.

Auth required: no

#### New User Request

```json
{
  "email": "vivek@example.com",
  "invite_code": "PERSONAL-CODE-123"
}
```

#### Returning User Request

```json
{
  "email": "vivek@example.com"
}
```

#### Success Response

```json
{
  "message": "If this request is valid, a code has been sent."
}
```

#### Errors

Missing, invalid, expired, or already-used invite codes return the same response:

```json
{
  "error": {
    "code": "invalid_invite_code",
    "message": "Invite code is invalid or unavailable."
  }
}
```

### POST /api/auth/otp/verify

Verify an OTP and create a session.

Auth required: no

#### Request

```json
{
  "email": "vivek@example.com",
  "code": "123456"
}
```

#### Success Response

```json
{
  "token": "raw_session_token_once",
  "profile_required": true,
  "user": {
    "id": 1,
    "email": "vivek@example.com",
    "display_name": null,
    "bio": null
  }
}
```

#### Errors

```json
{
  "error": {
    "code": "invalid_otp",
    "message": "Code is invalid or expired."
  }
}
```

### DELETE /api/logout

Delete the current session.

Auth required: yes

#### Success Response

```json
{
  "message": "Logged out."
}
```

### GET /api/me

Return the current user.

Auth required: yes

#### Success Response

```json
{
  "user": {
    "id": 1,
    "email": "vivek@example.com",
    "display_name": "Vivek",
    "bio": "Building private chat tools.",
    "profile_completed_at": "2026-04-25T10:00:00Z"
  }
}
```

### PATCH /api/me

Update the current user's profile.

Auth required: yes

#### Request

```json
{
  "display_name": "Vivek",
  "bio": "Building private chat tools."
}
```

#### Success Response

```json
{
  "user": {
    "id": 1,
    "email": "vivek@example.com",
    "display_name": "Vivek",
    "bio": "Building private chat tools.",
    "profile_completed_at": "2026-04-25T10:00:00Z"
  }
}
```

### GET /api/users/search

Search users by email or display name before starting a chat.

Auth required: yes

#### Query Params

```text
query=viv
```

#### Success Response

```json
{
  "users": [
    {
      "id": 2,
      "email": "friend@example.com",
      "display_name": "Friend",
      "bio": "Early user."
    }
  ]
}
```

Rules:

- Exclude the current user.
- Only return users with completed profiles.

### GET /api/conversations

List conversations for the current user.

Auth required: yes

#### Success Response

```json
{
  "conversations": [
    {
      "id": 1,
      "kind": "direct",
      "recipient": {
        "id": 2,
        "email": "friend@example.com",
        "display_name": "Friend",
        "bio": "Early user."
      },
      "last_message": {
        "id": 10,
        "sender_id": 1,
        "body": "Check this https://example.com",
        "created_at": "2026-04-25T10:00:00Z"
      }
    }
  ]
}
```

### POST /api/conversations

Create or return a direct conversation.

Auth required: yes

#### Request

```json
{
  "recipient_id": 2
}
```

#### Success Response

```json
{
  "conversation": {
    "id": 1,
    "kind": "direct",
    "recipient": {
      "id": 2,
      "email": "friend@example.com",
      "display_name": "Friend",
      "bio": "Early user."
    }
  }
}
```

Rules:

- If the direct conversation already exists, return it.
- A user cannot create a conversation with themselves.
- Conversation responses expose `recipient`, not `members`, because the MVP only supports 1:1 chats.

### GET /api/conversations/:id

Return one conversation.

Auth required: yes

#### Success Response

```json
{
  "conversation": {
    "id": 1,
    "kind": "direct",
    "recipient": {
      "id": 2,
      "email": "friend@example.com",
      "display_name": "Friend",
      "bio": "Early user."
    },
    "last_message": {
      "id": 10,
      "sender_id": 1,
      "body": "Check this https://example.com",
      "created_at": "2026-04-25T10:00:00Z"
    },
    "last_read_message_id": 10,
    "created_at": "2026-04-25T09:50:00Z",
    "updated_at": "2026-04-25T10:00:00Z"
  }
}
```

Rules:

- Only members can view the conversation.
- This endpoint returns conversation metadata, not the message history.
- Use `GET /api/conversations/:conversation_id/messages` to load messages.

### POST /api/conversations/:id/read

Mark a conversation as read.

Auth required: yes

#### Request

```json
{
  "last_read_message_id": 10
}
```

#### Success Response

```json
{
  "conversation_id": 1,
  "last_read_message_id": 10
}
```

### GET /api/conversations/:conversation_id/messages

List messages in a conversation.

Auth required: yes

#### Query Params

```text
before_id=50
limit=30
```

#### Success Response

```json
{
  "messages": [
    {
      "id": 10,
      "conversation_id": 1,
      "sender_id": 1,
      "body": "Check this https://example.com",
      "created_at": "2026-04-25T10:00:00Z",
      "links": [
        {
          "id": 1,
          "url": "https://example.com",
          "domain": "example.com",
          "title": "Example Domain",
          "description": null,
          "status": "fetched",
          "fetched_at": "2026-04-25T10:00:03Z"
        }
      ]
    }
  ]
}
```

Rules:

- Only members can list messages.
- Default limit is 30.
- Maximum limit is 100.

### POST /api/conversations/:conversation_id/messages

Create a message.

Auth required: yes

#### Request

```json
{
  "body": "Check this https://example.com"
}
```

#### Success Response

```json
{
  "message": {
    "id": 10,
    "conversation_id": 1,
    "sender_id": 1,
    "body": "Check this https://example.com",
    "created_at": "2026-04-25T10:00:00Z",
    "links": [
      {
        "id": 1,
        "url": "https://example.com",
        "domain": "example.com",
        "title": null,
        "description": null,
        "status": "pending",
        "fetched_at": null
      }
    ]
  }
}
```

Rules:

- Only members can send messages.
- Body cannot be blank.
- Link preview fetch is queued after the message is saved.
- Messages cannot be edited after they are sent.
- Messages cannot be deleted after they are sent.

### GET /up

Rails health check.

Auth required: no

## Realtime WebSocket Events

WebSockets are used for realtime notifications. They do not replace the REST APIs.

REST remains the source of truth:

- Clients create conversations and messages through REST.
- Clients load conversation lists and message history through REST.
- WebSockets notify connected clients when something changed.

Connection:

```text
Development: ws://localhost:3000/cable?token=<session_token>
Production:  wss://your-domain.com/cable?token=<session_token>
```

Auth:

```text
token query param
```

Transport:

- Rails Action Cable handles WebSocket connections.
- Solid Cable backs Action Cable in production without Redis.
- Backend authenticates the socket by hashing the `token` query param and finding a valid `user_session`.
- If the token is missing, invalid, or expired, the socket connection is rejected.

Important frontend rule:

- Do not create conversations or send messages over WebSocket.
- Use REST for writes.
- Use WebSocket only for realtime notifications.

### ConversationChannel

Clients subscribe to conversation events for conversations where the current user is a member.

Subscription params:

```json
{
  "channel": "ConversationChannel",
  "conversation_id": 1
}
```

Raw Action Cable subscribe message:

```json
{
  "command": "subscribe",
  "identifier": "{\"channel\":\"ConversationChannel\",\"conversation_id\":1}"
}
```

Most Flutter Action Cable clients build this raw message internally. The frontend still needs to pass `channel: "ConversationChannel"` and `conversation_id`.

Rules:

- User must be authenticated.
- User must be a member of the conversation.
- Unauthorized subscriptions are rejected.

### message.created

Broadcast after `POST /api/conversations/:conversation_id/messages` succeeds.

```json
{
  "type": "message.created",
  "conversation_id": 1,
  "message_id": 10,
  "sender_id": 1,
  "created_at": "2026-04-25T10:00:00Z"
}
```

Client behavior:

- If the user is viewing that conversation, fetch or append the new message.
- If the user is on the inbox screen, refresh or update that conversation's `last_message`.

### conversation.read

Broadcast after `POST /api/conversations/:id/read` succeeds.

```json
{
  "type": "conversation.read",
  "conversation_id": 1,
  "user_id": 2,
  "last_read_message_id": 10,
  "created_at": "2026-04-25T10:01:00Z"
}
```

Client behavior:

- Update read state for the conversation.

### link_preview.updated

Broadcast after the Solid Queue link preview job finishes.

```json
{
  "type": "link_preview.updated",
  "conversation_id": 1,
  "message_id": 10,
  "link_id": 1,
  "status": "fetched",
  "updated_at": "2026-04-25T10:00:03Z"
}
```

Client behavior:

- Refresh the message or link preview data for `message_id`.

### Event Payload Rules

- WebSocket events should stay small.
- Events should include IDs and timestamps.
- REST APIs remain responsible for full resource payloads.
- WebSocket delivery is best-effort; clients should resync through REST when reconnecting.

### Reconnect Behavior

When the socket reconnects, the client should refresh server state through REST:

- Call `GET /api/conversations` to refresh the inbox.
- If a chat screen is open, call `GET /api/conversations/:conversation_id/messages` to refresh message history.

## Future Implementation Tests

- New-user OTP request requires a valid invite code.
- Existing-user OTP request does not require invite code.
- Invalid invite code does not send OTP.
- Invite code is consumed only after OTP verification succeeds.
- Invite code cannot be reused.
- OTP request creates a valid OTP and uses generic success messaging.
- OTP verify creates a new user if needed.
- OTP verify returns `profile_required: true` when name is missing.
- `PATCH /api/me` completes the user profile.
- Authenticated user can search other users.
- User cannot find themselves in user search.
- Creating a direct conversation works with a valid recipient.
- Creating the same direct conversation twice returns the existing conversation.
- User cannot access conversations they are not a member of.
- User can send and list messages in their own conversation.
- Message body extracts URLs into `message_links`.
- Link preview job updates `message_links` status, title, and description.
- Authenticated users can subscribe to conversations they belong to.
- Users cannot subscribe to conversations they do not belong to.
- `message.created` is broadcast after message creation.
- `conversation.read` is broadcast after read-state updates.
- `link_preview.updated` is broadcast after link preview jobs finish.
- Unauthenticated requests return `401`.

## Assumptions

- API version prefix is `/api`.
- Invite codes are single-use.
- Invite code is required only for first signup.
- Returning users login with email OTP only.
- Invite code is marked used only after OTP verification succeeds.
- OTPs expire after 10 minutes.
- Sessions expire after 30 days.
- Real email delivery is configured later.
- Development OTP delivery logs codes locally.
- REST APIs are the source of truth for reads and writes.
- WebSocket events are realtime notifications only.
