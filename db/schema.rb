# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_25_174133) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversation_members", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "last_read_message_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id", "user_id"], name: "index_conversation_members_on_conversation_id_and_user_id", unique: true
    t.index ["conversation_id"], name: "index_conversation_members_on_conversation_id"
    t.index ["last_read_message_id"], name: "index_conversation_members_on_last_read_message_id"
    t.index ["user_id"], name: "index_conversation_members_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "updated_at", null: false
  end

  create_table "email_otps", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invite_code_id"
    t.string "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_email_otps_on_email"
    t.index ["invite_code_id"], name: "index_email_otps_on_invite_code_id"
  end

  create_table "invite_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "label"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "used_by_user_id"
    t.index ["code_digest"], name: "index_invite_codes_on_code_digest", unique: true
    t.index ["used_by_user_id"], name: "index_invite_codes_on_used_by_user_id"
  end

  create_table "message_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain"
    t.datetime "fetched_at"
    t.bigint "message_id", null: false
    t.string "status", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["message_id"], name: "index_message_links_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email", null: false
    t.datetime "profile_completed_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "conversation_members", "conversations"
  add_foreign_key "conversation_members", "messages", column: "last_read_message_id"
  add_foreign_key "conversation_members", "users"
  add_foreign_key "email_otps", "invite_codes"
  add_foreign_key "invite_codes", "users", column: "used_by_user_id"
  add_foreign_key "message_links", "messages"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "user_sessions", "users"
end
