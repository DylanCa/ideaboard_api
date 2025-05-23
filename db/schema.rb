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

ActiveRecord::Schema[8.0].define(version: 2025_03_16_001502) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "github_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.bigint "github_id", null: false
    t.string "github_username", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_polled_at"
    t.index ["github_id"], name: "index_github_accounts_on_github_id", unique: true
    t.index ["github_username"], name: "index_github_accounts_on_github_username", unique: true
    t.index ["last_polled_at"], name: "index_github_accounts_on_last_polled_at"
    t.index ["user_id"], name: "index_github_accounts_on_user_id", unique: true
  end

  create_table "github_repositories", force: :cascade do |t|
    t.string "full_name", null: false
    t.integer "stars_count", default: 0, null: false
    t.integer "forks_count", default: 0, null: false
    t.boolean "has_contributing", default: false, null: false
    t.datetime "github_created_at", null: false
    t.text "description"
    t.boolean "is_fork", default: false, null: false
    t.boolean "archived", default: false, null: false
    t.boolean "disabled", default: false, null: false
    t.string "license"
    t.boolean "visible", default: true, null: false
    t.datetime "github_updated_at", null: false
    t.string "github_id", null: false
    t.string "author_username"
    t.string "language"
    t.integer "update_method", default: 0, null: false
    t.datetime "last_polled_at"
    t.string "webhook_secret"
    t.boolean "app_installed", default: false, null: false
    t.boolean "webhook_installed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "github_webhook_id"
    t.text "contributing_guidelines"
    t.string "contributing_url"
    t.index ["author_username", "stars_count"], name: "idx_repos_on_author_and_stars"
    t.index ["author_username"], name: "index_github_repositories_on_author_username"
    t.index ["full_name"], name: "index_github_repositories_on_full_name", unique: true
    t.index ["github_id"], name: "index_github_repositories_on_github_id", unique: true
    t.index ["github_updated_at"], name: "index_github_repositories_on_github_updated_at"
    t.index ["last_polled_at"], name: "index_github_repositories_on_last_polled_at"
    t.index ["stars_count", "visible", "archived", "disabled"], name: "idx_on_stars_count_visible_archived_disabled_2b4ce69e99"
    t.index ["update_method"], name: "index_github_repositories_on_update_method"
    t.index ["visible", "archived", "disabled"], name: "index_github_repositories_on_visible_and_archived_and_disabled"
  end

  create_table "github_repository_topics", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.integer "topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_repository_id", "topic_id"], name: "idx_on_github_repository_id_topic_id_43985769e2", unique: true
    t.index ["github_repository_id", "topic_id"], name: "index_repository_tags_uniqueness", unique: true
    t.index ["github_repository_id"], name: "index_github_repository_topics_on_github_repository_id"
    t.index ["topic_id"], name: "index_github_repository_topics_on_topic_id"
  end

  create_table "issue_labels", force: :cascade do |t|
    t.integer "issue_id", null: false
    t.integer "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id", "label_id"], name: "index_issue_labels_on_issue_id_and_label_id", unique: true
    t.index ["issue_id"], name: "index_issue_labels_on_issue_id"
    t.index ["label_id"], name: "index_issue_labels_on_label_id"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.string "github_id"
    t.string "title", null: false
    t.datetime "github_created_at", null: false
    t.datetime "github_updated_at", null: false
    t.string "url", null: false
    t.integer "number", null: false
    t.string "author_username"
    t.datetime "closed_at"
    t.integer "comments_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_username", "github_created_at"], name: "idx_issues_on_author_and_created_at"
    t.index ["author_username"], name: "index_issues_on_author_username"
    t.index ["github_id"], name: "index_issues_on_github_id", unique: true
    t.index ["github_repository_id", "author_username"], name: "index_issues_on_github_repository_id_and_author_username"
    t.index ["github_repository_id", "github_updated_at"], name: "index_issues_on_github_repository_id_and_github_updated_at"
    t.index ["github_repository_id", "number"], name: "index_issues_on_github_repository_id_and_number"
    t.index ["github_repository_id"], name: "index_issues_on_github_repository_id"
  end

  create_table "labels", force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.text "description"
    t.boolean "is_bug", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "github_repository_id", null: false
    t.index ["github_repository_id"], name: "index_labels_on_github_repository_id"
    t.index ["name", "github_repository_id"], name: "idx_labels_on_name_and_repo_id"
  end

  create_table "pull_request_issues", force: :cascade do |t|
    t.string "pr_repository", null: false
    t.integer "pr_number", null: false
    t.string "issue_repository", null: false
    t.integer "issue_number", null: false
    t.boolean "closes_issue", default: true, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_repository", "issue_number"], name: "idx_on_issue_repo_and_number"
    t.index ["pr_repository", "pr_number", "issue_repository", "issue_number"], name: "idx_on_pr_issue_unique", unique: true
    t.index ["pr_repository", "pr_number"], name: "idx_on_pr_repo_and_number"
    t.index ["processed_at"], name: "index_pull_request_issues_on_processed_at"
  end

  create_table "pull_request_labels", force: :cascade do |t|
    t.integer "pull_request_id", null: false
    t.integer "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["label_id"], name: "index_pull_request_labels_on_label_id"
    t.index ["pull_request_id", "label_id"], name: "index_pull_request_labels_on_pull_request_id_and_label_id", unique: true
    t.index ["pull_request_id"], name: "index_pull_request_labels_on_pull_request_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.string "github_id"
    t.string "title", null: false
    t.datetime "merged_at"
    t.datetime "github_created_at", null: false
    t.datetime "github_updated_at", null: false
    t.string "url", null: false
    t.integer "number", null: false
    t.string "author_username"
    t.boolean "is_draft", default: false, null: false
    t.integer "commits"
    t.integer "total_comments_count"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_username", "github_created_at"], name: "idx_prs_on_author_and_created_at"
    t.index ["author_username", "merged_at"], name: "index_pull_requests_on_author_username_and_merged_at"
    t.index ["author_username"], name: "index_pull_requests_on_author_username"
    t.index ["github_id"], name: "index_pull_requests_on_github_id", unique: true
    t.index ["github_repository_id", "author_username"], name: "idx_on_github_repository_id_author_username_558298bf1e"
    t.index ["github_repository_id", "github_updated_at"], name: "idx_on_github_repository_id_github_updated_at_965a46efdb"
    t.index ["github_repository_id", "number"], name: "index_pull_requests_on_github_repository_id_and_number"
    t.index ["github_repository_id"], name: "index_pull_requests_on_github_repository_id"
    t.index ["merged_at"], name: "index_pull_requests_on_merged_at"
  end

  create_table "reputation_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "github_repository_id"
    t.bigint "pull_request_id"
    t.bigint "issue_id"
    t.integer "points_change", null: false
    t.jsonb "points_breakdown", null: false
    t.string "event_type", null: false
    t.string "description"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_reputation_events_on_event_type"
    t.index ["github_repository_id"], name: "index_reputation_events_on_github_repository_id"
    t.index ["issue_id"], name: "index_reputation_events_on_issue_id"
    t.index ["occurred_at"], name: "index_reputation_events_on_occurred_at"
    t.index ["pull_request_id"], name: "index_reputation_events_on_pull_request_id"
    t.index ["user_id", "occurred_at"], name: "index_reputation_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_reputation_events_on_user_id"
  end

  create_table "token_usage_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "github_repository_id"
    t.string "query", null: false
    t.string "variables"
    t.integer "usage_type", null: false
    t.integer "points_used", null: false
    t.integer "points_remaining", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at", "user_id"], name: "idx_token_usage_logs_on_created_at_and_user_id"
    t.index ["github_repository_id"], name: "index_token_usage_logs_on_github_repository_id"
    t.index ["query", "created_at"], name: "index_token_usage_logs_on_query_and_created_at"
    t.index ["query"], name: "index_token_usage_logs_on_query"
    t.index ["usage_type"], name: "index_token_usage_logs_on_usage_type"
    t.index ["user_id", "github_repository_id"], name: "index_token_usage_logs_on_user_id_and_github_repository_id"
    t.index ["user_id"], name: "index_token_usage_logs_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_topics_on_name", unique: true
  end

  create_table "user_repository_stats", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "github_repository_id", null: false
    t.integer "opened_prs_count", default: 0, null: false
    t.integer "merged_prs_count", default: 0, null: false
    t.integer "issues_opened_count", default: 0, null: false
    t.integer "issues_closed_count", default: 0, null: false
    t.integer "issues_with_pr_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "closed_prs_count", default: 0, null: false
    t.datetime "last_contribution_at"
    t.datetime "first_contribution_at"
    t.integer "contribution_streak", default: 0, null: false
    t.index ["github_repository_id"], name: "index_user_repository_stats_on_github_repository_id"
    t.index ["last_contribution_at"], name: "index_user_repository_stats_on_last_contribution_at"
    t.index ["user_id", "github_repository_id"], name: "idx_on_user_id_github_repository_id_b7aa4510b5", unique: true
    t.index ["user_id"], name: "index_user_repository_stats_on_user_id"
  end

  create_table "user_stats", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reputation_points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reputation_points"], name: "index_user_stats_on_reputation_points"
    t.index ["user_id"], name: "index_user_stats_on_user_id", unique: true
  end

  create_table "user_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_tokens_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.integer "account_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "token_usage_level", default: 0
    t.index ["account_status"], name: "index_users_on_account_status"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "github_accounts", "users"
  add_foreign_key "github_repository_topics", "github_repositories"
  add_foreign_key "github_repository_topics", "topics"
  add_foreign_key "issue_labels", "issues"
  add_foreign_key "issue_labels", "labels"
  add_foreign_key "issues", "github_repositories"
  add_foreign_key "labels", "github_repositories"
  add_foreign_key "pull_request_labels", "labels"
  add_foreign_key "pull_request_labels", "pull_requests"
  add_foreign_key "pull_requests", "github_repositories"
  add_foreign_key "reputation_events", "github_repositories"
  add_foreign_key "reputation_events", "issues"
  add_foreign_key "reputation_events", "pull_requests"
  add_foreign_key "reputation_events", "users"
  add_foreign_key "token_usage_logs", "github_repositories"
  add_foreign_key "token_usage_logs", "users"
  add_foreign_key "user_repository_stats", "github_repositories"
  add_foreign_key "user_repository_stats", "users"
  add_foreign_key "user_stats", "users"
  add_foreign_key "user_tokens", "users"
end
