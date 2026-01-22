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

ActiveRecord::Schema[8.0].define(version: 2026_01_21_090000) do
  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "actor_type", null: false
    t.string "action", null: false
    t.json "metadata", default: {}
    t.string "ip_hash"
    t.string "user_agent_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "delivery_tokens", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.string "token_digest", null: false
    t.datetime "revoked_at"
    t.datetime "last_accessed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id", "created_at"], name: "index_delivery_tokens_on_recipient_id_and_created_at"
    t.index ["recipient_id"], name: "index_delivery_tokens_on_recipient_id"
    t.index ["token_digest"], name: "index_delivery_tokens_on_token_digest", unique: true
  end

  create_table "email_events", force: :cascade do |t|
    t.string "provider", null: false
    t.string "event_type", null: false
    t.string "message_id"
    t.string "recipient_email_hash"
    t.datetime "event_timestamp"
    t.json "raw_json", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_email_events_on_created_at"
    t.index ["event_type"], name: "index_email_events_on_event_type"
    t.index ["message_id"], name: "index_email_events_on_message_id"
  end

  create_table "magic_link_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.string "ip_hash"
    t.string "user_agent_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_magic_link_tokens_on_expires_at"
    t.index ["token_digest"], name: "index_magic_link_tokens_on_token_digest", unique: true
    t.index ["user_id", "created_at"], name: "index_magic_link_tokens_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_magic_link_tokens_on_user_id"
  end

  create_table "message_recipients", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.bigint "recipient_id", null: false
    t.text "encrypted_msg_key_b64u", null: false
    t.string "envelope_algo", default: "crypto_box_seal", null: false
    t.integer "envelope_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "recipient_id"], name: "index_message_recipients_on_message_id_and_recipient_id", unique: true
    t.index ["message_id"], name: "index_message_recipients_on_message_id"
    t.index ["recipient_id"], name: "index_message_recipients_on_recipient_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "label"
    t.text "ciphertext_b64u", null: false
    t.text "nonce_b64u", null: false
    t.string "aead_algo", default: "xchacha20poly1305_ietf", null: false
    t.integer "payload_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_messages_on_created_at"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "recipient_keys", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.text "public_key_b64u", null: false
    t.text "kdf_salt_b64u", null: false
    t.json "kdf_params", default: {}, null: false
    t.integer "key_version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id"], name: "index_recipient_keys_on_recipient_id", unique: true
  end

  create_table "recipients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "email", null: false
    t.string "name"
    t.string "state", default: "invited", null: false
    t.string "invite_token_digest"
    t.datetime "invite_sent_at"
    t.datetime "invite_expires_at"
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_token_digest"], name: "index_recipients_on_invite_token_digest", unique: true
    t.index ["state"], name: "index_recipients_on_state"
    t.index ["user_id", "email"], name: "index_recipients_on_user_id_and_email", unique: true
    t.index ["user_id"], name: "index_recipients_on_user_id"
  end

  create_table "trusted_contacts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "email", null: false
    t.string "name"
    t.string "token_digest"
    t.datetime "token_expires_at"
    t.integer "ping_interval_hours"
    t.integer "pause_duration_hours"
    t.datetime "last_pinged_at"
    t.datetime "last_confirmed_at"
    t.datetime "paused_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_trusted_contacts_on_token_digest", unique: true
    t.index ["user_id"], name: "index_trusted_contacts_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.integer "checkin_interval_hours"
    t.integer "grace_period_hours"
    t.integer "cooldown_period_hours"
    t.string "state", default: "active", null: false
    t.datetime "next_checkin_at"
    t.datetime "last_checkin_confirmed_at"
    t.datetime "grace_started_at"
    t.datetime "cooldown_started_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "checkin_token_digest"
    t.string "panic_token_digest"
    t.string "recovery_code_digest"
    t.datetime "recovery_code_viewed_at"
    t.index ["checkin_token_digest"], name: "index_users_on_checkin_token_digest", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["next_checkin_at"], name: "index_users_on_next_checkin_at"
    t.index ["panic_token_digest"], name: "index_users_on_panic_token_digest", unique: true
    t.index ["state", "cooldown_started_at"], name: "index_users_on_state_and_cooldown_started_at"
    t.index ["state", "grace_started_at"], name: "index_users_on_state_and_grace_started_at"
    t.index ["state", "next_checkin_at"], name: "index_users_on_state_and_next_checkin_at"
    t.index ["state"], name: "index_users_on_state"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "delivery_tokens", "recipients"
  add_foreign_key "magic_link_tokens", "users"
  add_foreign_key "message_recipients", "messages"
  add_foreign_key "message_recipients", "recipients"
  add_foreign_key "messages", "users"
  add_foreign_key "recipient_keys", "recipients"
  add_foreign_key "recipients", "users"
  add_foreign_key "trusted_contacts", "users"
end
