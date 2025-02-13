class RenamedLicenseKeyToLicenseInRepo < ActiveRecord::Migration[8.0]
  def change
    rename_column :github_repositories, :license_key, :license
  end
end
