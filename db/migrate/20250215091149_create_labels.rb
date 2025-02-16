class CreateLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :labels do |t|
      t.string :name, null: false
      t.string :color
      t.text :description
      t.boolean :is_bug, default: false
      t.timestamps
    end

    add_index :labels, :name, unique: true
  end
end
