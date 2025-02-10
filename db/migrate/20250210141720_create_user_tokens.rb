class CreateUserTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :user_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :access_token, null: false
      t.string :refresh_token, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end
end
