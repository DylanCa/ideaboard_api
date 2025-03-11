# spec/sidekiq/webhook_event_processor_worker_spec.rb
require 'rails_helper'

RSpec.describe WebhookEventProcessorWorker do
  let(:repository) { create(:github_repository, full_name: "owner/repo") }

  describe '#execute' do
    context 'with pull request event' do
      let(:github_event) { 'pull_request' }
      let(:payload) do
        {
          'action' => 'opened',
          'pull_request' => {
            'node_id' => 'pr_node_id',
            'number' => 123,
            'title' => 'Test PR',
            'html_url' => 'https://github.com/owner/repo/pull/123',
            'user' => { 'login' => 'test_user' },
            'draft' => false,
            'merged_at' => nil,
            'closed_at' => nil,
            'created_at' => '2025-01-01T00:00:00Z',
            'updated_at' => '2025-01-01T00:00:00Z',
            'labels' => [
              { 'name' => 'bug', 'color' => 'ff0000' }
            ]
          }
        }
      end

      before do
        allow(GithubRepository).to receive(:find_by).with(id: repository.id).and_return(repository)
        allow(PullRequest).to receive(:find_by).and_return(nil)
        allow(PullRequest).to receive(:create!)
        allow(Persistence::Helper).to receive(:preload_labels)
        allow(Persistence::Helper).to receive(:get_label_by_name)
        allow(LoggerExtension).to receive(:log)
      end

      it 'processes pull request event and creates PR record' do
        result = subject.execute(github_event, payload, repository.id)

        expect(result).to include(
                            repository_id: repository.id,
                            repository: repository.full_name,
                            event: github_event,
                            action: 'opened',
                            processed: true
                          )

        expect(PullRequest).to have_received(:create!).with(
          hash_including(
            github_id: 'pr_node_id',
            number: 123,
            title: 'Test PR',
            github_repository_id: repository.id
          )
        )
      end

      context 'when PR already exists' do
        let(:existing_pr) { create(:pull_request, github_id: 'pr_node_id', github_repository: repository) }

        before do
          allow(PullRequest).to receive(:find_by).with(github_id: 'pr_node_id').and_return(existing_pr)
          allow(existing_pr).to receive(:update)
        end

        it 'updates the existing PR' do
          subject.execute(github_event, payload, repository.id)

          expect(existing_pr).to have_received(:update).with(
            hash_including(
              title: 'Test PR',
              github_repository_id: repository.id
            )
          )
        end
      end
    end

    context 'with issue event' do
      let(:github_event) { 'issues' }
      let(:payload) do
        {
          'action' => 'opened',
          'issue' => {
            'node_id' => 'issue_node_id',
            'number' => 123,
            'title' => 'Test Issue',
            'html_url' => 'https://github.com/owner/repo/issues/123',
            'user' => { 'login' => 'test_user' },
            'closed_at' => nil,
            'created_at' => '2025-01-01T00:00:00Z',
            'updated_at' => '2025-01-01T00:00:00Z',
            'comments' => 0,
            'labels' => [
              { 'name' => 'bug', 'color' => 'ff0000' }
            ]
          }
        }
      end

      before do
        allow(GithubRepository).to receive(:find_by).with(id: repository.id).and_return(repository)
        allow(Issue).to receive(:find_by).and_return(nil)
        allow(Issue).to receive(:create!)
        allow(Persistence::Helper).to receive(:preload_labels)
        allow(Persistence::Helper).to receive(:get_label_by_name)
        allow(LoggerExtension).to receive(:log)
      end

      it 'processes issue event and creates Issue record' do
        result = subject.execute(github_event, payload, repository.id)

        expect(result).to include(
                            repository_id: repository.id,
                            repository: repository.full_name,
                            event: github_event,
                            action: 'opened',
                            processed: true
                          )

        expect(Issue).to have_received(:create!).with(
          hash_including(
            github_id: 'issue_node_id',
            number: 123,
            title: 'Test Issue',
            github_repository_id: repository.id
          )
        )
      end

      context 'when issue is a pull request' do
        let(:payload) do
          {
            'action' => 'opened',
            'issue' => {
              'node_id' => 'issue_node_id',
              'number' => 123,
              'title' => 'Test Issue',
              'html_url' => 'https://github.com/owner/repo/issues/123',
              'user' => { 'login' => 'test_user' },
              'closed_at' => nil,
              'created_at' => '2025-01-01T00:00:00Z',
              'updated_at' => '2025-01-01T00:00:00Z',
              'comments' => 0,
              'labels' => [],
              'pull_request' => { 'url': 'https://api.github.com/repos/owner/repo/pulls/123' }
            }
          }
        end

        it 'skips processing for pull request issues' do
          subject.execute(github_event, payload, repository.id)

          expect(Issue).not_to have_received(:create!)
        end
      end

      context 'when issue already exists' do
        let(:existing_issue) { create(:issue, github_id: 'issue_node_id', github_repository: repository) }

        before do
          allow(Issue).to receive(:find_by).with(github_id: 'issue_node_id').and_return(existing_issue)
          allow(existing_issue).to receive(:update)
        end

        it 'updates the existing issue' do
          subject.execute(github_event, payload, repository.id)

          expect(existing_issue).to have_received(:update).with(
            hash_including(
              title: 'Test Issue',
              github_repository_id: repository.id
            )
          )
        end
      end

      context 'when issue is closed' do
        let(:payload) do
          {
            'action' => 'closed',
            'issue' => {
              'node_id' => 'issue_node_id',
              'number' => 123,
              'title' => 'Test Issue',
              'html_url' => 'https://github.com/owner/repo/issues/123',
              'user' => { 'login' => 'test_user' },
              'closed_at' => '2025-01-02T00:00:00Z',
              'created_at' => '2025-01-01T00:00:00Z',
              'updated_at' => '2025-01-02T00:00:00Z',
              'comments' => 0,
              'labels' => []
            }
          }
        end

        let(:user) { create(:user) }

        before do
          allow(User).to receive_message_chain(:joins, :where, :first).and_return(user)
          allow(UserRepositoryStatWorker).to receive(:perform_async)
        end

        it 'updates user repository stats' do
          subject.execute(github_event, payload, repository.id)

          expect(UserRepositoryStatWorker).to have_received(:perform_async).with(user.id, repository.id)
        end
      end
    end

    context 'with repository event' do
      let(:github_event) { 'repository' }
      let(:payload) do
        {
          'action' => 'edited',
          'repository' => {
            'full_name' => repository.full_name
          }
        }
      end

      before do
        allow(GithubRepository).to receive(:find_by).with(id: repository.id).and_return(repository)
        allow(RepositoryFetcherWorker).to receive(:perform_async)
        allow(LoggerExtension).to receive(:log)
      end

      it 'processes repository event and schedules repository update' do
        result = subject.execute(github_event, payload, repository.id)

        expect(result).to include(
                            repository_id: repository.id,
                            repository: repository.full_name,
                            event: github_event,
                            action: 'edited',
                            processed: true
                          )

        expect(RepositoryFetcherWorker).to have_received(:perform_async).with(repository.full_name)
      end
    end

    context 'with unknown event type' do
      let(:github_event) { 'unknown_event' }
      let(:payload) { { 'action' => 'test' } }

      before do
        allow(GithubRepository).to receive(:find_by).with(id: repository.id).and_return(repository)
        allow(LoggerExtension).to receive(:log)
      end

      it 'logs the unknown event and returns processed status' do
        result = subject.execute(github_event, payload, repository.id)

        expect(result).to include(
                            repository_id: repository.id,
                            repository: repository.full_name,
                            event: github_event,
                            action: 'test',
                            processed: true
                          )

        expect(LoggerExtension).to have_received(:log).with(
          :error,
          "Unhandled webhook event type",
          hash_including(repository: repository.full_name, event: github_event)
        )
      end
    end

    context 'when repository is not found' do
      let(:github_event) { 'push' }
      let(:payload) { {} }

      before do
        allow(GithubRepository).to receive(:find_by).with(id: repository.id).and_return(nil)
      end

      it 'returns nil' do
        result = subject.execute(github_event, payload, repository.id)
        expect(result).to be_nil
      end
    end
  end
end
