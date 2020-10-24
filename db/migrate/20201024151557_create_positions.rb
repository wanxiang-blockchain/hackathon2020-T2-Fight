class CreatePositions < ActiveRecord::Migration[6.0]
  def change
    create_table :positions do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :latitude
      t.decimal :longitude

      t.timestamps
    end
  end
end
