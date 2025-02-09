class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true, index: true

      t.timestamps
    end
  end
end
