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

ActiveRecord::Schema[8.0].define(version: 2025_02_09_175456) do
  create_table "github_accounts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "github_id", limit: 8, null: false
    t.string "github_username", null: false
    t.string "oauth_access_token", null: false
    t.string "oauth_refresh_token", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_github_accounts_on_github_id", unique: true
    t.index ["github_username"], name: "index_github_accounts_on_github_username", unique: true
    t.index ["user_id"], name: "index_github_accounts_on_user_id", unique: true
  end

  create_table "github_repositories", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "language_id", null: false
    t.integer "repo_id", limit: 8, null: false
    t.string "full_name", null: false
    t.integer "stars_count", default: 0, null: false
    t.integer "forks_count", default: 0, null: false
    t.integer "open_issues_count", default: 0, null: false
    t.boolean "has_license", default: false, null: false
    t.boolean "has_contributing", default: false, null: false
    t.datetime "github_created_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_github_repositories_on_full_name", unique: true
    t.index ["language_id"], name: "index_github_repositories_on_language_id"
    t.index ["project_id"], name: "index_github_repositories_on_project_id", unique: true
    t.index ["repo_id"], name: "index_github_repositories_on_repo_id", unique: true
  end

  create_table "github_repository_tags", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_repository_id", "tag_id"], name: "index_repository_tags_uniqueness", unique: true
    t.index ["github_repository_id"], name: "index_github_repository_tags_on_github_repository_id"
    t.index ["tag_id"], name: "index_github_repository_tags_on_tag_id"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.integer "github_id", limit: 8, null: false
    t.string "github_username", null: false
    t.string "title", null: false
    t.integer "state", default: 0, null: false
    t.integer "difficulty", default: 0, null: false
    t.datetime "github_created_at", null: false
    t.datetime "github_updated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["difficulty"], name: "index_issues_on_difficulty"
    t.index ["github_id"], name: "index_issues_on_github_id", unique: true
    t.index ["github_repository_id"], name: "index_issues_on_github_repository_id"
    t.index ["github_username"], name: "index_issues_on_github_username"
    t.index ["state"], name: "index_issues_on_state"
  end

  create_table "languages", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_languages_on_name", unique: true
  end

  create_table "project_stats", force: :cascade do |t|
    t.integer "project_id", null: false
    t.float "rank_score", default: 0.0, null: false
    t.datetime "last_activity_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_stats_on_project_id", unique: true
    t.index ["rank_score"], name: "index_project_stats_on_rank_score"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_projects_on_active"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "github_repository_id", null: false
    t.integer "github_id", limit: 8, null: false
    t.string "github_username", null: false
    t.string "title", null: false
    t.integer "state", default: 0, null: false
    t.datetime "merged_at"
    t.integer "points_awarded", default: 0, null: false
    t.datetime "github_created_at", null: false
    t.datetime "github_updated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_pull_requests_on_github_id", unique: true
    t.index ["github_repository_id"], name: "index_pull_requests_on_github_repository_id"
    t.index ["github_username"], name: "index_pull_requests_on_github_username"
    t.index ["merged_at"], name: "index_pull_requests_on_merged_at"
    t.index ["state"], name: "index_pull_requests_on_state"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "user_stats", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reputation_points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reputation_points"], name: "index_user_stats_on_reputation_points"
    t.index ["user_id"], name: "index_user_stats_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "email", null: false
    t.integer "account_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_status"], name: "index_users_on_account_status"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "github_accounts", "users"
  add_foreign_key "github_repositories", "languages"
  add_foreign_key "github_repositories", "projects"
  add_foreign_key "github_repository_tags", "github_repositories"
  add_foreign_key "github_repository_tags", "tags"
  add_foreign_key "issues", "github_repositories"
  add_foreign_key "project_stats", "projects"
  add_foreign_key "projects", "users"
  add_foreign_key "pull_requests", "github_repositories"
  add_foreign_key "user_stats", "users"
end
