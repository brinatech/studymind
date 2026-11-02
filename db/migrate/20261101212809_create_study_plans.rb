class CreateStudyPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :study_plans do |t|
      t.string :title, null: false
      t.text :objective, null: false
      t.string :current_level, null: false
      t.date :deadline, null: false
      t.decimal :daily_hours, precision: 4, scale: 2, null: false
      t.string :available_days, array: true, default: [], null: false
      t.text :goal, null: false
      t.timestamps
    end
  end
end
