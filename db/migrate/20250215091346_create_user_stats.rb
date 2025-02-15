class CreateUserStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_stats do |t|
      t.integer :user_id, null: false
      t.integer :reputation_points, default: 0, null: false
      t.timestamps
    end

    add_index :user_stats, :user_id, unique: true
    add_index :user_stats, :reputation_points

    add_foreign_key :user_stats, :users
  end
end
