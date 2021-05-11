# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_05_07_102315) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

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
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "attachments", force: :cascade do |t|
    t.string "file"
    t.string "name"
    t.string "target_type"
    t.bigint "target_id"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "content_type"
    t.index ["target_type", "target_id"], name: "index_attachments_on_target_type_and_target_id"
    t.index ["user_id"], name: "index_attachments_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "text"
    t.string "target_type"
    t.bigint "target_id"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["target_type", "target_id"], name: "index_comments_on_target_type_and_target_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.text "description", default: "", null: false
    t.integer "discount", default: 0, null: false
    t.integer "discount_type", default: 0, null: false
    t.integer "min_items", default: 1, null: false
    t.boolean "enabled", default: false, null: false
    t.boolean "auto", default: false, null: false
    t.boolean "archived", default: false, null: false
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "max_items"
    t.string "course_package_tags", default: [], null: false, array: true
    t.index ["code"], name: "index_coupons_on_code", unique: true
  end

  create_table "course_categories", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["parent_id"], name: "index_course_categories_on_parent_id"
  end

  create_table "course_clans", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "description", default: "", null: false
    t.integer "score", default: 0, null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "average_image_color", default: "#000000"
    t.bigint "mentor_id"
    t.integer "members_count", default: 0, null: false
    t.index ["course_id"], name: "index_course_clans_on_course_id"
    t.index ["mentor_id"], name: "index_course_clans_on_mentor_id"
  end

  create_table "course_clans_users", force: :cascade do |t|
    t.bigint "course_clan_id"
    t.bigint "user_id"
    t.bigint "course_id"
    t.index ["course_clan_id"], name: "index_course_clans_users_on_course_clan_id"
    t.index ["course_id"], name: "index_course_clans_users_on_course_id"
    t.index ["user_id"], name: "index_course_clans_users_on_user_id"
  end

  create_table "course_mentors", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_course_mentors_on_course_id"
    t.index ["user_id"], name: "index_course_mentors_on_user_id"
  end

  create_table "course_module_results", force: :cascade do |t|
    t.bigint "module_id", null: false
    t.bigint "user_id", null: false
    t.boolean "finished", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["module_id"], name: "index_course_module_results_on_module_id"
    t.index ["user_id"], name: "index_course_module_results_on_user_id"
  end

  create_table "course_module_unit_results", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "state"
    t.index ["unit_id"], name: "index_course_module_unit_results_on_unit_id"
    t.index ["user_id"], name: "index_course_module_unit_results_on_user_id"
  end

  create_table "course_module_units", force: :cascade do |t|
    t.string "name", limit: 150
    t.string "unit_content_type"
    t.bigint "unit_content_id"
    t.integer "serial_number", null: false
    t.integer "unit_type", limit: 2, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "course_module_id"
    t.boolean "published", default: false
    t.datetime "start_date"
    t.datetime "deadline"
    t.index ["course_module_id"], name: "index_course_module_units_on_course_module_id"
    t.index ["unit_content_type", "unit_content_id"], name: "index_units_on_unit_content_type_and_unit_content_id"
  end

  create_table "course_module_units_packages", id: false, force: :cascade do |t|
    t.bigint "course_package_id", null: false
    t.bigint "course_module_unit_id", null: false
  end

  create_table "course_module_units_subscription_types", id: false, force: :cascade do |t|
    t.bigint "course_module_unit_id", null: false
    t.bigint "subscription_type_id", null: false
  end

  create_table "course_modules", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "published", default: false, null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "serial_number", default: 0
    t.index ["course_id"], name: "index_course_modules_on_course_id"
  end

  create_table "course_package_groups", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "published", default: false, null: false
    t.bigint "course_id", null: false
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_course_package_groups_on_course_id"
  end

  create_table "course_package_user_subscriptions", force: :cascade do |t|
    t.bigint "course_package_id", null: false
    t.bigint "user_id", null: false
    t.bigint "subscription_type_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_package_id"], name: "index_course_package_user_subscriptions_on_course_package_id"
    t.index ["subscription_type_id"], name: "index_course_package_user_subscriptions_on_subscription_type_id"
    t.index ["user_id"], name: "index_course_package_user_subscriptions_on_user_id"
  end

  create_table "course_packages", force: :cascade do |t|
    t.string "name", null: false
    t.integer "price", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "description", default: "", null: false
    t.bigint "course_package_group_id", null: false
    t.boolean "active", default: false, null: false
    t.date "start_date"
    t.integer "validity"
    t.integer "validity_type"
    t.string "tags", default: [], null: false, array: true
    t.boolean "published", default: true, null: false
    t.index ["course_package_group_id"], name: "index_course_packages_on_course_package_group_id"
  end

  create_table "course_packages_user_course_package_orders", id: false, force: :cascade do |t|
    t.uuid "user_course_package_order_id"
    t.bigint "course_package_id"
    t.index ["course_package_id"], name: "user_course_package_orders_join_packages_package_index"
    t.index ["user_course_package_order_id"], name: "user_course_package_orders_join_packages_order_index"
  end

  create_table "course_user_mentors", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "course_id"
    t.bigint "mentor_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_course_user_mentors_on_course_id"
    t.index ["mentor_id"], name: "index_course_user_mentors_on_mentor_id"
    t.index ["user_id"], name: "index_course_user_mentors_on_user_id"
  end

  create_table "course_users", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id", "user_id"], name: "index_course_users_on_course_id_and_user_id"
    t.index ["course_id"], name: "index_course_users_on_course_id"
    t.index ["user_id"], name: "index_course_users_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "name", null: false
    t.string "description", default: "", null: false
    t.boolean "published", default: false, null: false
    t.integer "lives", limit: 2
    t.bigint "teacher_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "serial_number", limit: 2
    t.bigint "course_category_id"
    t.string "average_image_color", default: "#000000"
    t.json "settings", default: {"integrations"=>{}}
    t.index ["course_category_id"], name: "index_courses_on_course_category_id"
    t.index ["teacher_id"], name: "index_courses_on_teacher_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["target_type", "target_id"], name: "index_messages_on_target_type_and_target_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "practice_results", force: :cascade do |t|
    t.bigint "practice_id", null: false
    t.bigint "user_id", null: false
    t.integer "state", default: 0, null: false
    t.integer "score"
    t.integer "attempt", default: 0, null: false
    t.bigint "mentor_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "review"
    t.datetime "check_time"
    t.datetime "completion_time"
    t.index ["mentor_id"], name: "index_practice_results_on_mentor_id"
    t.index ["practice_id"], name: "index_practice_results_on_practice_id"
    t.index ["user_id"], name: "index_practice_results_on_user_id"
  end

  create_table "practices", force: :cascade do |t|
    t.integer "passing_score", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "successful_messages", array: true
    t.string "rejected_messages", array: true
    t.string "failed_messages", array: true
    t.string "description", default: ""
  end

  create_table "salebot_clients", force: :cascade do |t|
    t.string "name"
    t.integer "client_type", limit: 2
    t.string "default_tag"
    t.string "group"
    t.string "vk_id"
    t.jsonb "variables"
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_salebot_clients_on_user_id"
  end

  create_table "subscription_types", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.string "name", default: "", null: false
    t.integer "practice_attempts"
    t.boolean "free", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_subscription_types_on_course_id"
  end

  create_table "task_answer_results", force: :cascade do |t|
    t.bigint "task_answer_id", null: false
    t.bigint "checker_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "review", default: {}
    t.index ["checker_id"], name: "index_task_answer_results_on_checker_id"
    t.index ["task_answer_id"], name: "index_task_answer_results_on_task_answer_id"
  end

  create_table "task_answers", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.integer "answer_type", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "answer", default: {}
    t.bigint "practice_result_id"
    t.bigint "checker_id"
    t.json "review"
    t.index ["checker_id"], name: "index_task_answers_on_checker_id"
    t.index ["practice_result_id"], name: "index_task_answers_on_practice_result_id"
    t.index ["task_id"], name: "index_task_answers_on_task_id"
    t.index ["user_id"], name: "index_task_answers_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "practice_id", null: false
    t.string "name"
    t.integer "answer_type", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "question"
    t.json "solution"
    t.json "answer"
    t.index ["practice_id"], name: "index_tasks_on_practice_id"
  end

  create_table "text_units", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "content", default: {}
  end

  create_table "user_course_package_orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.text "phone_number"
    t.integer "state", default: 0, null: false
    t.integer "price", null: false
    t.bigint "user_id"
    t.bigint "creator_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "coupon_id"
    t.json "payment_data"
    t.boolean "external_payment", default: false
    t.string "description", default: ""
    t.string "username", default: ""
    t.index ["coupon_id"], name: "index_user_course_package_orders_on_coupon_id"
    t.index ["creator_id"], name: "index_user_course_package_orders_on_creator_id"
    t.index ["user_id"], name: "index_user_course_package_orders_on_user_id"
  end

  create_table "user_course_results", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "user_id", null: false
    t.integer "score", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["course_id"], name: "index_user_course_results_on_course_id"
    t.index ["user_id"], name: "index_user_course_results_on_user_id"
  end

  create_table "user_course_subscriptions", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "user_id", null: false
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "subscription_type_id"
    t.index ["course_id"], name: "index_user_course_subscriptions_on_course_id"
    t.index ["subscription_type_id"], name: "index_user_course_subscriptions_on_subscription_type_id"
    t.index ["user_id"], name: "index_user_course_subscriptions_on_user_id"
  end

  create_table "user_ratings", force: :cascade do |t|
    t.integer "course_rating"
    t.integer "clan_rating"
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.bigint "clan_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["clan_id"], name: "index_user_ratings_on_clan_id"
    t.index ["course_id"], name: "index_user_ratings_on_course_id"
    t.index ["user_id"], name: "index_user_ratings_on_user_id"
  end

  create_table "user_scores", force: :cascade do |t|
    t.integer "score", limit: 2, default: 0, null: false
    t.string "description", default: "", null: false
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.bigint "author_id"
    t.string "source_type"
    t.bigint "source_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["author_id"], name: "index_user_scores_on_author_id"
    t.index ["course_id"], name: "index_user_scores_on_course_id"
    t.index ["source_type", "source_id"], name: "index_user_scores_on_source_type_and_source_id"
    t.index ["user_id", "updated_at"], name: "index_user_scores_on_user_id_and_updated_at", order: { updated_at: :desc }
    t.index ["user_id"], name: "index_user_scores_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "screen_name"
    t.string "last_name", default: "", null: false
    t.string "email"
    t.string "access_token"
    t.string "image"
    t.string "uid"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "role", default: 0
    t.string "phone"
    t.string "provider", limit: 20, default: "vk"
    t.jsonb "utm"
    t.string "salebot_tags", array: true
    t.date "salebot_date_of_creation"
    t.bigint "inviting_user_id"
    t.integer "discount_coins", default: 0
    t.jsonb "statistics"
    t.index ["inviting_user_id"], name: "index_users_on_inviting_user_id"
    t.index ["provider", "screen_name"], name: "index_users_on_provider_and_screen_name", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "video_units", force: :cascade do |t|
    t.string "url", default: "", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "video_type", limit: 2, default: 0
    t.json "content", default: {}
  end

  create_table "webinars", force: :cascade do |t|
    t.string "url", default: "", null: false
    t.integer "state", limit: 2, null: false
    t.datetime "start_datetime"
    t.time "duration"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "content", default: {}
    t.string "codeword"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "course_clans", "courses"
  add_foreign_key "course_clans_users", "course_clans"
  add_foreign_key "course_clans_users", "courses"
  add_foreign_key "course_clans_users", "users"
  add_foreign_key "course_module_units", "course_modules"
  add_foreign_key "course_modules", "courses"
  add_foreign_key "course_package_groups", "courses"
  add_foreign_key "course_package_user_subscriptions", "course_packages"
  add_foreign_key "course_package_user_subscriptions", "subscription_types"
  add_foreign_key "course_package_user_subscriptions", "users"
  add_foreign_key "course_packages", "course_package_groups"
  add_foreign_key "course_packages_user_course_package_orders", "course_packages"
  add_foreign_key "course_packages_user_course_package_orders", "user_course_package_orders"
  add_foreign_key "courses", "course_categories"
  add_foreign_key "messages", "users"
  add_foreign_key "subscription_types", "courses"
  add_foreign_key "task_answers", "practice_results"
  add_foreign_key "task_answers", "users", column: "checker_id"
  add_foreign_key "user_course_package_orders", "coupons"
  add_foreign_key "user_ratings", "courses"
  add_foreign_key "user_ratings", "users"
  add_foreign_key "users", "users", column: "inviting_user_id"
end
