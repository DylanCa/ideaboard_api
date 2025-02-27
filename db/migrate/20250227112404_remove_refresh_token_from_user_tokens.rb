class RemoveRefreshTokenFromUserTokens < ActiveRecord::Migration[8.0]
  def change
    remove_column :user_tokens, :refresh_token, :string
    remove_column :user_tokens, :expires_at, :datetime
  end
end
