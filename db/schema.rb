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

ActiveRecord::Schema[8.0].define(version: 2025_12_04_171224) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "blog_posts", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.text "content"
    t.text "excerpt"
    t.string "meta_description"
    t.string "meta_keywords"
    t.boolean "published"
    t.datetime "published_at"
    t.string "author"
    t.integer "reading_time"
    t.integer "view_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
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

  create_table "partner_applications", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "partner_type"
    t.text "message"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_partner_applications_on_email"
    t.index ["status"], name: "index_partner_applications_on_status"
  end

  create_table "prompt_completions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "prompt_identifier", null: false
    t.datetime "completed_at", null: false
    t.integer "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_prompt_completions_on_session_id"
    t.index ["user_id", "prompt_identifier"], name: "index_prompt_completions_on_user_id_and_prompt_identifier", unique: true
    t.index ["user_id"], name: "index_prompt_completions_on_user_id"
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
    t.integer "weekly_focus_id"
    t.boolean "is_planned_session", default: false, null: false
    t.date "planned_for_date"
    t.json "micro_tips", default: []
    t.json "coaching_insights", default: {}
    t.json "analysis_data", default: {}
    t.datetime "processing_started_at"
    t.float "relevance_score"
    t.text "relevance_feedback"
    t.boolean "off_topic", default: false
    t.integer "retake_count", default: 0
    t.boolean "is_retake", default: false
    t.text "prompt_text"
    t.index ["analysis_json"], name: "index_sessions_on_analysis_json_gin"
    t.index ["completed", "created_at"], name: "index_sessions_on_completed_and_created_at"
    t.index ["created_at", "completed"], name: "index_sessions_on_date_completed"
    t.index ["minimum_duration_enforced"], name: "index_sessions_on_duration_enforced"
    t.index ["minimum_duration_enforced"], name: "index_sessions_on_minimum_duration_enforced"
    t.index ["planned_for_date", "completed"], name: "index_sessions_on_planned_for_date_and_completed"
    t.index ["processing_state"], name: "index_sessions_on_processing_state"
    t.index ["user_id", "completed", "created_at"], name: "index_sessions_on_user_completed_date"
    t.index ["user_id", "completed"], name: "index_sessions_on_user_and_completed"
    t.index ["user_id", "created_at"], name: "index_sessions_on_user_and_created_at"
    t.index ["user_id", "planned_for_date"], name: "index_sessions_on_user_id_and_planned_for_date"
    t.index ["user_id", "processing_state"], name: "index_sessions_on_user_processing_state"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.index ["weekly_focus_id", "completed"], name: "index_sessions_on_weekly_focus_id_and_completed"
    t.index ["weekly_focus_id"], name: "index_sessions_on_weekly_focus_id"
  end

  create_table "stripe_events", force: :cascade do |t|
    t.string "stripe_event_id"
    t.string "event_type"
    t.datetime "processed_at"
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_event_id"], name: "index_stripe_events_on_stripe_event_id", unique: true
  end

  create_table "trial_sessions", force: :cascade do |t|
    t.string "token", null: false
    t.string "title", null: false
    t.string "language", default: "en"
    t.string "media_kind", default: "audio"
    t.integer "target_seconds", default: 30
    t.integer "duration_ms"
    t.text "analysis_data"
    t.string "processing_state", default: "pending"
    t.boolean "completed", default: false
    t.datetime "processed_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "incomplete_reason"
    t.text "error_text"
    t.boolean "is_mock", default: false, null: false
    t.datetime "processing_started_at"
    t.index ["created_at"], name: "index_trial_sessions_on_created_at"
    t.index ["expires_at"], name: "index_trial_sessions_on_expires_at"
    t.index ["processing_state"], name: "index_trial_sessions_on_processing_state"
    t.index ["token"], name: "index_trial_sessions_on_token", unique: true
  end

  create_table "user_issue_embeddings", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "embedding_json"
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "session_id"
    t.string "embedding_type"
    t.integer "reference_id"
    t.text "vector_data"
    t.string "ai_model_name"
    t.integer "dimensions"
    t.text "metadata_json"
    t.index ["session_id", "embedding_type", "reference_id"], name: "index_embeddings_on_session_type_ref"
    t.index ["session_id"], name: "index_user_issue_embeddings_on_session_id"
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
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status", default: "free_trial"
    t.string "subscription_plan"
    t.datetime "trial_expires_at"
    t.datetime "last_qualifying_session_at"
    t.datetime "subscription_started_at"
    t.datetime "current_period_end"
    t.text "speaking_goal", default: "[]"
    t.string "speaking_style"
    t.string "age_range"
    t.string "profession"
    t.string "preferred_pronouns"
    t.datetime "onboarding_completed_at"
    t.integer "onboarding_demo_session_id"
    t.datetime "trial_starts_at"
    t.string "stripe_payment_method_id"
    t.integer "payment_retry_count", default: 0, null: false
    t.string "preferred_language", default: "en", null: false
    t.boolean "admin", default: false, null: false
    t.string "apple_subscription_id"
    t.string "revenuecat_customer_id"
    t.string "subscription_platform"
    t.integer "target_wpm"
    t.string "promo_code"
    t.string "google_uid"
    t.string "apple_uid"
    t.string "auth_provider"
    t.json "tours_completed", default: {}
    t.index ["apple_subscription_id"], name: "index_users_on_apple_subscription_id"
    t.index ["apple_uid"], name: "index_users_on_apple_uid", unique: true, where: "apple_uid IS NOT NULL"
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true, where: "google_uid IS NOT NULL"
    t.index ["preferred_language"], name: "index_users_on_preferred_language"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["revenuecat_customer_id"], name: "index_users_on_revenuecat_customer_id"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_users_on_stripe_subscription_id"
    t.index ["subscription_platform"], name: "index_users_on_subscription_platform"
    t.index ["subscription_status"], name: "index_users_on_subscription_status"
    t.index ["trial_expires_at"], name: "index_users_on_trial_expires_at"
  end

  create_table "weekly_focuses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "focus_type", null: false
    t.decimal "target_value", precision: 10, scale: 4, null: false
    t.decimal "starting_value", precision: 10, scale: 4, null: false
    t.date "week_start", null: false
    t.date "week_end", null: false
    t.integer "target_sessions_per_week", default: 10, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_weekly_focuses_on_status"
    t.index ["user_id", "status"], name: "index_weekly_focuses_on_user_id_and_status"
    t.index ["user_id", "week_start"], name: "index_weekly_focuses_on_user_id_and_week_start"
    t.index ["user_id"], name: "index_weekly_focuses_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "issues", "sessions"
  add_foreign_key "prompt_completions", "sessions"
  add_foreign_key "prompt_completions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sessions", "weekly_focuses", column: "weekly_focus_id"
  add_foreign_key "user_issue_embeddings", "sessions"
  add_foreign_key "user_issue_embeddings", "users"
  add_foreign_key "weekly_focuses", "users"
end
