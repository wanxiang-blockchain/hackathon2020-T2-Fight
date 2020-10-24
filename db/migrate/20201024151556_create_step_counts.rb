class CreateStepCounts < ActiveRecord::Migration[6.0]
  def change
    create_table :step_counts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :step_count
      t.decimal :calculated_calories

      t.timestamps
    end
  end
end
