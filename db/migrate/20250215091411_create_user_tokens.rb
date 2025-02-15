class CreateUserTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :user_tokens do |t|
      t.integer :user_id, null: false
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :user_tokens, :user_id
    add_index :user_tokens, :refresh_token, unique: true

    add_foreign_key :user_tokens, :users
  end
end