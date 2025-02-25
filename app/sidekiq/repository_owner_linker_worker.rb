# Create a new worker to link repositories to users
class RepositoryOwnerLinkerWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform
    # Find repositories without owners but with matching usernames
    unlinked_repos = GithubRepository.where(owner_id: nil).where.not(author_username: nil)

    linked_count = 0
    unlinked_repos.find_each do |repo|
      user = User.joins(:github_account)
                 .find_by(github_accounts: { github_username: repo.author_username })

      if user
        repo.update(owner_id: user.id)
        linked_count += 1
        LoggerExtension.log(:info, "Linked repository #{repo.full_name} to user #{user.id}")
      end
    end

    LoggerExtension.log(:info, "Repository linking completed. Linked #{linked_count} repositories")
  end
end