class UpdateUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.boolean :allow_token_usage, null: false, default: false
    end
  end
end