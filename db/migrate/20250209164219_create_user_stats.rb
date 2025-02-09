class CreateUserStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_stats do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :reputation_points, null: false, default: 0, index: true

      t.timestamps
    end
  end
end
