require 'rails_helper'

RSpec.describe IssueLabel, type: :model do
  subject { create(:issue_label) }

  describe 'associations' do
    it { should belong_to(:issue) }
    it { should belong_to(:label) }
  end

  describe 'validations' do
    it { should validate_presence_of(:issue_id) }
    it { should validate_presence_of(:label_id) }
    it { should validate_uniqueness_of(:issue_id).scoped_to(:label_id) }
  end

  describe 'creation' do
    let(:issue) { create(:issue) }
    let(:label) { create(:label) }

    it 'creates a valid issue-label association' do
      issue_label = IssueLabel.new(
        issue: issue,
        label: label
      )
      expect(issue_label).to be_valid
    end
  end
end
