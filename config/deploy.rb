default_run_options[:pty] = true

set :application, "bugs"
set :repository,  "git@github.com:taf2/redmine.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

ssh_options[:forward_agent] = true
set :branch, "origin/master"
set :deploy_via, :remote_cache
set :deploy_to, "/var/www/apps/#{application}"

role :web, "slice5"                          # Your HTTP server, Apache/etc
role :app, "slice5"                          # This may be the same as your `Web` server
role :db,  "slice2", :primary => true # This is where Rails migrations will run
#role :db,  "slice2"
set :port, 222
set :user, 'deployer'
set :tmpdir_remote, "/var/www/apps/#{application}/tmp/"
set :tmpdir_local, File.join(File.dirname(__FILE__),'..','tmp')
set :use_sudo, false

namespace :deploy do
  desc "Deploy"
  task :default do
    update
    restart
    cleanup
  end
 
  desc "Setup a Git-style deployment."
  task :setup, :except => { :no_release => true } do
    run "git clone #{repository} #{current_path}"
  end
 
  desc "Update the deployed code."
  task :update_code, :except => { :no_release => true } do
    run "cd #{current_path}; git fetch origin; git reset --hard #{branch}"
  end
 
  namespace :rollback do
    desc "Rollback a single commit."
    task :code, :except => { :no_release => true } do
      set :branch, "HEAD^"
      deploy.default
    end

    task :default do
      rollback.code
    end
  end
end

set :normal_symlinks, %w(
  config/database.yml
)
set :weird_symlinks, {
  'system'             => 'public/system'
}

namespace :symlinks do
  desc "Make all the damn symlinks"
  task :make, :roles => :app, :except => { :no_release => true } do
    commands = normal_symlinks.map do |path|
      "rm -rf #{release_path}/#{path} && \
       ln -s #{shared_path}/#{path} #{release_path}/#{path}"
    end
 
    commands += weird_symlinks.map do |from, to|
      "rm -rf #{release_path}/#{to} && \
       ln -s #{shared_path}/#{from} #{release_path}/#{to}"
    end
 
    # needed for some of the symlinks
    run "mkdir -p #{current_path}/tmp"
 
    run <<-CMD
      cd #{release_path} &&
      #{commands.join(" && ")}
    CMD
  end
end
after "deploy:update_code", "symlinks:make"
