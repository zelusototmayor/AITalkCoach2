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

ActiveRecord::Schema[8.0].define(version: 2025_09_27_201121) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_caches", primary_key: "key", id: :string, force: :cascade do |t|
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_caches_on_created_at"
    t.index ["updated_at"], name: "index_ai_caches_on_updated_at"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "session_id", null: false
    t.string "kind"
    t.float "label_confidence"
    t.integer "start_ms"
    t.integer "end_ms"
    t.text "text"
    t.text "rationale"
    t.string "source"
    t.text "rewrite"
    t.text "tip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category", null: false
    t.string "severity"
    t.text "coaching_note"
    t.index ["category"], name: "index_issues_on_category"
    t.index ["session_id", "category", "severity"], name: "index_issues_on_session_category_severity"
    t.index ["session_id", "category"], name: "index_issues_on_session_and_category"
    t.index ["session_id", "start_ms"], name: "index_issues_on_session_and_start_ms"
    t.index ["session_id", "start_ms"], name: "index_issues_on_session_start_time"
    t.index ["session_id"], name: "index_issues_on_session_id"
    t.index ["severity"], name: "index_issues_on_severity"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title"
    t.string "language"
    t.string "media_kind"
    t.integer "duration_ms"
    t.integer "target_seconds"
    t.boolean "completed"
    t.string "incomplete_reason"
    t.string "processing_state"
    t.text "error_text"
    t.text "analysis_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "processed_at"
    t.boolean "minimum_duration_enforced", default: true, null: false
    t.string "speech_context"
    t.index ["analysis_json"], name: "index_sessions_on_analysis_json_gin"
    t.index ["completed", "created_at"], name: "index_sessions_on_completed_and_created_at"
    t.index ["created_at", "completed"], name: "index_sessions_on_date_completed"
    t.index ["minimum_duration_enforced"], name: "index_sessions_on_duration_enforced"
    t.index ["minimum_duration_enforced"], name: "index_sessions_on_minimum_duration_enforced"
    t.index ["processing_state"], name: "index_sessions_on_processing_state"
    t.index ["user_id", "completed", "created_at"], name: "index_sessions_on_user_completed_date"
    t.index ["user_id", "completed"], name: "index_sessions_on_user_and_completed"
    t.index ["user_id", "created_at"], name: "index_sessions_on_user_and_created_at"
    t.index ["user_id", "processing_state"], name: "index_sessions_on_user_processing_state"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "user_issue_embeddings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "embedding_json"
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_embeddings_on_user_date"
    t.index ["user_id", "created_at"], name: "index_user_embeddings_on_user_and_created_at"
    t.index ["user_id"], name: "index_user_issue_embeddings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "auto_delete_audio_days", default: 30
    t.boolean "privacy_mode", default: false
    t.boolean "delete_processed_audio", default: true
    t.string "name"
    t.string "password_digest"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "issues", "sessions"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_issue_embeddings", "users"
end
