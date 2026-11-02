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

ActiveRecord::Schema[8.1].define(version: 2026_11_01_212809) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "study_plans", force: :cascade do |t|
    t.string "title", null: false
    t.text "objective", null: false
    t.string "current_level", null: false
    t.date "deadline", null: false
    t.decimal "daily_hours", precision: 4, scale: 2, null: false
    t.string "available_days", default: [], null: false, array: true
    t.text "goal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
