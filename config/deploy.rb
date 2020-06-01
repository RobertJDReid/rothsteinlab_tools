# config valid only for Capistrano 3.1
lock '3.2.1'

site5_rails_root = 'tools'
set :application, "rothstein_web_tools"
set :scm, :git
set :repo_url, 'git@bitbucket.org:jdittmar/rothstein-rails-4-repo.git'
set :ssh_options, { forward_agent: true }
set :deploy_to, "/home/rothstei/#{fetch(:application)}"
set :tmp_dir, '/home/rothstei/tmp/capistrano'
set :deploy_via, :remote_cache
set :run_method, :run

set :default_env, {
  "RAILS_RELATIVE_URL_ROOT" => "/#{site5_rails_root}"
}

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/database.yml public/.htaccess}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle}


# ssh_options[:verbose] = :debug

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5


# after 'deploy:update_code' do
#   run <<-CMD
#   cd #{release_path} &&
#   ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml &&
#   ln -nfs #{shared_path}/public/.htaccess #{release_path}/public/.htaccess
#   CMD
#   run_locally("rake assets:clean && rake assets:precompile")
#   upload("public/assets", "#{release_path}/public/assets", via: :scp, recursive: true)
#   run_locally("rake assets:clean")
# end


namespace :deploy do

  # Clear existing task so we can replace it rather than "add" to it.
  Rake::Task["deploy:compile_assets"].clear

  desc 'Compile assets'
  task compile_assets: [:set_rails_env] do
    invoke 'deploy:assets:precompile_local'
    invoke 'deploy:assets:backup_manifest'
  end

  desc 'Create Symbolic Links'
  task create_symbolic_links: [:set_rails_env] do
    invoke 'deploy:links:create_links'
  end

  desc 'Add scope to routes file'
  task add_scope: [:set_rails_env] do
    invoke 'deploy:routes:add_relative_scope'
  end

  namespace :links do
    task :create_links do
      on roles(:web) do
        within release_path do
          execute "ln -s ~/#{fetch(:application)}/current/public/cgi-bin/ ~/#{fetch(:application)}/current/cgi-bin"
          execute "ln -s ~/#{fetch(:application)}/current/public/ ~/#{fetch(:application)}/current/public/public"
          execute "ln -s ~/#{fetch(:application)}/current/public/ ~/#{fetch(:application)}/current/public/tools"
          execute "ln -s ~/#{fetch(:application)}/current/ ~/#{site5_rails_root}"
        end
      end
    end
  end

  namespace :routes do
    task :add_relative_scope do
      on roles (:web) do
        within release_path do
          execute "sed -i '/^Rails4App\:\:Application\.routes\.draw\ do/a scope \"/#{site5_rails_root}\" do' ~/#{fetch(:application)}/current/config/routes.rb"
          execute "echo 'end' >> ~/#{fetch(:application)}/current/config/routes.rb"
        end
      end
    end
  end

  namespace :data_scripts do
    desc "Run scripts to update data"
    task :perl_scripts do
      on roles (:web) do
        execute "cd ~/#{site5_rails_root}/public/cgi-bin; perl update_key_files.pl"
        execute "cd ~/#{site5_rails_root}/public/cgi-bin; perl updateBioGRID.plx"
      end
    end
  end

  namespace :assets do
    desc "Precompile assets locally and then rsync to web servers"
    task :precompile_local do
      # compile assets locally
      run_locally do
        execute "RAILS_ENV=#{fetch(:stage)} RAILS_RELATIVE_URL_ROOT='/#{site5_rails_root}' bundle exec rake assets:precompile"
      end

      # rsync to each server
      local_dir = "./public/assets/"
      on roles( fetch(:assets_roles, [:web]) ) do
        # this needs to be done outside run_locally in order for host to exist
        remote_dir = "#{host.user}@#{host.hostname}:#{release_path}/public/assets/"
        run_locally { execute "rsync -av --delete #{local_dir} #{remote_dir}" }
      end
      # clean up
      run_locally { execute "rm -rf #{local_dir}" }
    end
  end

  after :deploy, 'deploy:create_symbolic_links'
  after :deploy, 'deploy:add_scope'
  after :deploy, 'deploy:data_scripts:perl_scripts'
  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      execute "touch ~/#{fetch(:application)}/current/tmp/restart.txt"
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
