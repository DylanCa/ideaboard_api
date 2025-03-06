require 'rails_helper'

RSpec.describe 'Factories' do
  describe 'User factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'creates a user with github account when using the with_github_account trait' do
      user = create(:user, :with_github_account)
      expect(user.github_account).not_to be_nil
    end

    it 'creates a user with access token when using the with_access_token trait' do
      user = create(:user, :with_access_token)
      expect(user.user_token).not_to be_nil
      expect(user.user_token.access_token).to eq('test_access_token')
    end
  end

  describe 'GithubAccount factory' do
    it 'creates a valid github account' do
      github_account = build(:github_account)
      expect(github_account).to be_valid
    end
  end

  describe 'UserToken factory' do
    it 'creates a valid user token' do
      user_token = build(:user_token)
      expect(user_token).to be_valid
    end
  end

  describe 'GithubRepository factory' do
    it 'creates a valid github repository' do
      repository = build(:github_repository)
      expect(repository).to be_valid
    end
  end

  # Add factory specs for all relevant models
  %i[
    pull_request
    issue
    label
    pull_request_label
    issue_label
    topic
    github_repository_topic
    user_repository_stat
    user_stat
    token_usage_log
    rate_limit_log
  ].each do |factory_name|
    describe "#{factory_name.to_s.classify} factory" do
      it "creates a valid #{factory_name.to_s.humanize.downcase}" do
        pending "Factory #{factory_name} needs to be created"
        record = build(factory_name)
        expect(record).to be_valid
      end
    end
  end
end
