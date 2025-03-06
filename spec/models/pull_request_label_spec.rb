require 'rails_helper'

RSpec.describe PullRequestLabel, type: :model do
  subject { create(:pull_request_label) }

  describe 'associations' do
    it { should belong_to(:pull_request) }
    it { should belong_to(:label) }
  end

  describe 'validations' do
    it { should validate_presence_of(:pull_request_id) }
    it { should validate_presence_of(:label_id) }
    it { should validate_uniqueness_of(:pull_request_id).scoped_to(:label_id) }
  end

  describe 'creation' do
    let(:pull_request) { create(:pull_request) }
    let(:label) { create(:label) }

    it 'creates a valid pull request-label association' do
      pr_label = PullRequestLabel.new(
        pull_request: pull_request,
        label: label
      )
      expect(pr_label).to be_valid
    end
  end
end
