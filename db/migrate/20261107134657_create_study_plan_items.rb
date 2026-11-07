class CreateStudyPlanItems < ActiveRecord::Migration[8.1]
  def change
    create_table :study_plan_items do |t|
      t.references :study_plan, null: false, foreign_key: true
      t.integer :week, null: false
      t.string :day, null: false
      t.string :topic, null: false
      t.integer :duration_minutes, null: false
      t.text :activity, null: false
      t.timestamps
    end
  add_check_constraint :study_plan_items, "week > 0", name: "study_plan_items_week_positive"
  add_check_constraint :study_plan_items, "duration_minutes > 0", name: tudy_plan_items_duration_positive
  end
end
