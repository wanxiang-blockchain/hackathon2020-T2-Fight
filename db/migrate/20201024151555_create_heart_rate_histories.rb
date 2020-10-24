class CreateHeartRateHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :heart_rate_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :heartbeat_per_minute
      t.datetime :meature_time

      t.timestamps
    end
  end
end
