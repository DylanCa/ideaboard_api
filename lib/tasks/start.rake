namespace :start do
  desc 'Start Rails server and Sidekiq worker for normal development'
  task :development do
    exec 'foreman start -f Procfile.dev'
  end

  desc 'Start Rails server and Sidekiq worker with debugger enabled'
  task :debug do
    exec 'foreman start -f Procfile.debug'
  end
end