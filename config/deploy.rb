#require 'capistrano/ext/multistage'
default_run_options[:pty] = true

set :application, "qiangzuo"
set :user, "yzhang"
set :repository, "git@github.com:yzhang/Confforge.git"
set :scm, :git
set :deploy_via, :remote_cache

role :app, "f.51qiangzuo.com", :primary => true
role :web, "f.51qiangzuo.com"
role :db,  "f.51qiangzuo.com", :primary => true

namespace :deploy do
  set :deploy_to, "/home/yzhang/app/biaodan"  
  
  desc "Custom after update code to put production database.yml in place."
  task :copy_configs, :roles => :app do
    run "cp #{deploy_to}/shared/mongo_mapper.rb #{current_path}/config/initializers/mongo_mapper.rb"
    run "cd #{deploy_to}/current/vendor && ln -s #{deploy_to}/shared/bundle bundle"
    run "cd #{deploy_to}/current && bundle install --deployment"
  end
  
  desc "Long deploy will update the code migrate the database and restart the servers"
  task :master do
    # put up the maintenance screen
    #     ENV['REASON'] = 'an application upgrade'
    #     ENV['UNTIL']  = Time.now.+(600).strftime("%H:%M %Z")
    #     web.disable
    set :deploy_to, "/home/yzhang/app/qd"
    set :branch, "master"
    set :env, "production"
    
    transaction do
      update_code
      symlink
      copy_configs
      migrate
    end
    
    restart

    # remove the maintenance screen
    #web.enable
  end
  
  task :conf do
    # put up the maintenance screen
    #     ENV['REASON'] = 'an application upgrade'
    #     ENV['UNTIL']  = Time.now.+(600).strftime("%H:%M %Z")
    #     web.disable
    set :deploy_to, "/home/yzhang/app/biaodan"
    set :branch, "conf"
    set :env, "production"
    
    transaction do
      update_code
      symlink
      copy_configs
      migrate
    end
    
    restart

    # remove the maintenance screen
    #web.enable
  end
  
  task :staging do
    # put up the maintenance screen
    #     ENV['REASON'] = 'an application upgrade'
    #     ENV['UNTIL']  = Time.now.+(600).strftime("%H:%M %Z")
    #     web.disable
    set :deploy_to, "/home/yzhang/dev/biaodan"
    set :branch, "conf"
    set :env, "production"
    
    transaction do
      update_code
      symlink
      copy_configs
      migrate
    end
    
    restart

    # remove the maintenance screen
    #web.enable
  end
  
  desc "Rake database"
  task :migrate, :roles => :app, :only => {:primary => true} do
    run "cd #{deploy_to}/current/public && ln -s . add_expires_header"
    run "cd #{deploy_to}/current && rm -rf public/stylesheets/*.cache.css"
    run "cd #{deploy_to}/current && rm -rf public/javascripts/*.cache.js"
  end
  
  desc "Restart the app server"
  task :restart, :roles => :app do
    run "cd #{deploy_to}/current && touch tmp/restart.txt"
  end
    
  desc "Tail the Rails log..."
  task :tail_logs, :roles => :app do
    run "tail -f #{deploy_to}/current/log/#{env}.log" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:server]} -> #{data}" 
      break if stream == :err    
    end
  end
end
