class CreateStudyPlanItems < ActiveRecord::Migration[8.1]
  def change
    create_table :study_plan_items do |t|
      t.timestamps
    end
  end
end
