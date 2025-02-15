class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.integer :account_status, null: false
      t.boolean :allow_token_usage, default: false, null: false
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :account_status
  end
end
