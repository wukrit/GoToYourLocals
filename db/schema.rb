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

ActiveRecord::Schema[8.0].define(version: 2025_05_29_012135) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.integer "startgg_id"
    t.string "name"
    t.string "slug"
    t.integer "num_entrants"
    t.integer "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["startgg_id"], name: "index_events_on_startgg_id", unique: true
    t.index ["tournament_id"], name: "index_events_on_tournament_id"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "startgg_id"
    t.string "round"
    t.integer "round_number"
    t.string "identifier"
    t.string "full_round_text"
    t.string "display_score"
    t.integer "event_id", null: false
    t.integer "winner_id"
    t.integer "loser_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_matches_on_event_id"
    t.index ["startgg_id"], name: "index_matches_on_startgg_id", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "start_at"
    t.datetime "end_at"
    t.boolean "is_online"
    t.string "venue_name"
    t.string "city"
    t.string "state"
    t.string "country_code"
    t.bigint "startgg_id"
    t.json "images"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["startgg_id"], name: "index_tournaments_on_startgg_id", unique: true
  end

  create_table "user_event_participations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "event_id", null: false
    t.integer "final_placement"
    t.integer "entrant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_user_event_participations_on_event_id"
    t.index ["user_id"], name: "index_user_event_participations_on_user_id"
  end

  create_table "user_match_participations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "match_id", null: false
    t.boolean "is_winner"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_user_match_participations_on_match_id"
    t.index ["user_id"], name: "index_user_match_participations_on_user_id"
  end

  create_table "user_tournament_participations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "tournament_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tournament_id"], name: "index_user_tournament_participations_on_tournament_id"
    t.index ["user_id"], name: "index_user_tournament_participations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "tag"
    t.string "startgg_access_token"
    t.string "startgg_refresh_token"
    t.datetime "startgg_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "events", "tournaments"
  add_foreign_key "matches", "events"
  add_foreign_key "user_event_participations", "events"
  add_foreign_key "user_event_participations", "users"
  add_foreign_key "user_match_participations", "matches"
  add_foreign_key "user_match_participations", "users"
  add_foreign_key "user_tournament_participations", "tournaments"
  add_foreign_key "user_tournament_participations", "users"
end
