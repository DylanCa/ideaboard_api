require 'rails_helper'

RSpec.describe 'Factories' do
  describe 'User factory' do
    it 'creates a valid user' do
      user = create(:user)
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
      # The factory should automatically create a user association
      github_account = create(:github_account)
      expect(github_account).to be_valid
    end
  end

  describe 'UserToken factory' do
    it 'creates a valid user token' do
      user_token = create(:user_token)
      expect(user_token).to be_valid
    end
  end

  describe 'GithubRepository factory' do
    it 'creates a valid github repository' do
      repository = create(:github_repository)
      expect(repository).to be_valid
    end
  end

  describe 'PullRequest factory' do
    it 'creates a valid pull request' do
      pull_request = create(:pull_request)
      expect(pull_request).to be_valid
    end
  end

  describe 'Issue factory' do
    it 'creates a valid issue' do
      issue = create(:issue)
      expect(issue).to be_valid
    end
  end

  describe 'Label factory' do
    it 'creates a valid label' do
      label = create(:label)
      expect(label).to be_valid
    end
  end

  describe 'PullRequestLabel factory' do
    it 'creates a valid pull request label' do
      pull_request_label = create(:pull_request_label)
      expect(pull_request_label).to be_valid
    end
  end

  describe 'IssueLabel factory' do
    it 'creates a valid issue label' do
      issue_label = create(:issue_label)
      expect(issue_label).to be_valid
    end
  end

  describe 'Topic factory' do
    it 'creates a valid topic' do
      topic = create(:topic)
      expect(topic).to be_valid
    end
  end

  describe 'GithubRepositoryTopic factory' do
    it 'creates a valid github repository topic' do
      github_repository_topic = create(:github_repository_topic)
      expect(github_repository_topic).to be_valid
    end
  end

  describe 'UserRepositoryStat factory' do
    it 'creates a valid user repository stat' do
      user_repository_stat = create(:user_repository_stat)
      expect(user_repository_stat).to be_valid
    end
  end

  describe 'UserStat factory' do
    it 'creates a valid user stat' do
      user_stat = create(:user_stat)
      expect(user_stat).to be_valid
    end
  end

  describe 'TokenUsageLog factory' do
    it 'creates a valid token usage log' do
      token_usage_log = create(:token_usage_log)
      expect(token_usage_log).to be_valid
    end
  end
end
