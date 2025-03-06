class SetLabelNameToNotUnique < ActiveRecord::Migration[8.0]
  def change
    remove_index :labels, :name, unique: true
  end
end
