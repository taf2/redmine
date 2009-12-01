default_run_options[:pty] = true
#default_run_options[:max_hosts] = 1 # XXX: work around ssh bug in capistrano with ruby 1.8.6 p368 and ruby 1.8.7

set :application, "bugs"
set :repository,  "git@github.com:taf2/redmine.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

ssh_options[:forward_agent] = true
set :branch, "master"
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

namespace :rails do
  task :start, :roles => :web do
    run "cd #{current_path} && /home/deployer/ruby/bin/ruby script/spin start"
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf monitor all", :pty => true
  end

  desc "restart the rails process"
  task :reload, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf unmonitor all", :pty => true
    run "cd #{current_path} && /home/deployer/ruby/bin/ruby script/spin reload"
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf monitor all", :pty => true
  end

  desc "full on restart, the site will be down"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf unmonitor all", :pty => true
    run "cd #{current_path} && /home/deployer/ruby/bin/ruby script/spin restart"
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf monitor all", :pty => true
  end

  desc "stop the rails process"
  task :stop, :roles => :web do
    run "#{sudo} /usr/bin/monit -g bugs -c /etc/monit.conf unmonitor all", :pty => true
    run "cd #{current_path} && /home/deployer/ruby/bin/ruby script/spin stop"
  end
end

namespace :deploy do
  desc "restart all the processes"
  task :restart, :roles => :app, :except => { :no_release => true } do
    rails.reload
  end

  desc "start all processes"
  task :start, :roles => :web do
    rails.start
  end

  desc "stop all processes"
  task :stop, :roles => :web do
    rails.stop
  end
end

namespace :symlinks do
  desc "Make all the damn symlinks"
  task :make, :except => { :no_release => true } do
    run %{rm -f #{release_path}/config/database.yml && ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml} 
    run %{rm -f #{release_path}/config/auth_sources.yml && ln -s #{shared_path}/config/auth_sources.yml #{release_path}/config/auth_sources.yml} 
  end
end
after "deploy:update_code", "symlinks:make"
