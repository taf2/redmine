# see: http://github.com/blog/517-unicorn
# unicorn_rails -c /data/github/current/config/unicorn.rb -E production -D

rails_env = ENV['RAILS_ENV'] || 'production'

# 3 workers and 1 master
worker_processes (rails_env == 'production' ? 3 : 2)

# Load rails+github.git into the master before forking workers
# for super-fast worker spawn times
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 30

# Listen on a Unix data socket
listen '/var/www/apps/bugs/shared/tmp/sockets/unicorn.sock', :backlog => 1024


##
# REE

# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end


before_fork do |server, worker|
end


after_fork do |server, worker|
  ##
  # Unicorn master loads the app then forks off workers - because of the way
  # Unix forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection

  ActiveRecord::Base.establish_connection
  #CHIMNEY.client.connect_to_server
  # Redis and Memcached would go here but their connections are established
  # on demand, so the master never opens a socket

  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = '/var/www/apps/bugs/shared/pids/unicorn.pid.oldbin'
  #File.open(logfile, "a") {|f| f << "[#{Process]: check for old pid: #{old_pid} == #{server.pid}\n" } 

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      # make sure we don't send the winch and quit if we are the new master
      #File.open(logfile, "a") {|f| f <<  "[#{Process]: check pids: #{File.read(old_pid).to_i} - #{Process.pid}\n" } 
      if File.read(old_pid).to_i != Process.pid
        Process.kill("WINCH", File.read(old_pid).to_i)
        #File.open(logfile, "a") {|f| f << "[#{Process]: Sent old master the WINCH\n" } 
        sleep 0.1 # pause to give the master a second to register the winch
        Process.kill("QUIT", File.read(old_pid).to_i)
        #File.open(logfile, "a") {|f| f << "[#{Process]: Sent old master the QUIT\n" } 
      end
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end
