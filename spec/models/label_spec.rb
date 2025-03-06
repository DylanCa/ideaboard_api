require 'rails_helper'

RSpec.describe Label, type: :model do
  subject { create(:label) }

  describe 'associations' do
    it { should have_many(:issue_labels).dependent(:destroy) }
    it { should have_many(:issues).through(:issue_labels) }
    it { should have_many(:pull_request_labels).dependent(:destroy) }
    it { should have_many(:pull_requests).through(:pull_request_labels) }
    it { should belong_to(:github_repository) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:is_bug).in_array([ true, false ]) }
  end

  describe 'scopes' do
    let!(:bug_label) { create(:label, is_bug: true) }
    let!(:feature_label) { create(:label, is_bug: false) }
    let!(:red_label) { create(:label, color: 'ff0000') }
    let!(:blue_label) { create(:label, color: '0000ff') }

    describe '.bugs' do
      it 'returns only bug labels' do
        expect(Label.bugs).to include(bug_label)
        expect(Label.bugs).not_to include(feature_label)
      end
    end

    describe '.by_color' do
      it 'returns labels with the specified color' do
        expect(Label.by_color('ff0000')).to include(red_label)
        expect(Label.by_color('ff0000')).not_to include(blue_label)
      end
    end
  end
end
