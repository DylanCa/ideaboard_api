class Language < ApplicationRecord
  has_many :github_repositories

  before_save :downcase_name

  def downcase_name
    self.name.downcase!
  end
end
