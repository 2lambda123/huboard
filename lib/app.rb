require 'sinatra'
require 'sinatra/content_for'
require 'stint'
require 'encryptor'
require 'base64'
require_relative "helpers"

module Huboard
  class App < Sinatra::Base
    register Sinatra::Auth::Github
    register Huboard::Common


    enable :sessions

    set :views, settings.root + "/../views"

    puts "settings.root #{settings.root}"
    if File.exists? "#{File.dirname(__FILE__)}/../.settings"
      puts "settings file"
      token_file =  File.new("#{File.dirname(__FILE__)}/../.settings")
      eval(token_file.read) 
    end

    if ENV['GITHUB_CLIENT_ID']
      set :secret_key, ENV['SECRET_KEY']
      set :team_id, ENV["TEAM_ID"]
      set :user_name, ENV["USER_NAME"]
      set :password, ENV["PASSWORD"]
      set :github_options, {
        :secret    => ENV['GITHUB_SECRET'],
        :client_id => ENV['GITHUB_CLIENT_ID'],
        :scopes => "user,repo"
      }
      set :session_secret, ENV["SESSION_SECRET"]
    end

    get '/' do 
      @repos = pebble.all_repos
      erb :index
    end

    get '/:user/:repo/milestones' do 
      @parameters = params
      erb :milestones
    end
    get '/:user/:repo/board' do 
      @parameters = params
      erb :board, :layout => :layout_fluid
    end

    get '/:user/:repo/hook' do 
      json(pebble.create_hook( params[:user], params[:repo], "#{base_url}/webhook?token=#{encrypted_token}"))
    end

    post '/webhook' do 
      puts "webhook"
      token =  decrypt_token( params[:token] )
      hub = Stint::Pebble.new(Stint::Github.new({ :headers => {"Authorization" => "token #{token}"}}))

      payload = JSON.parse(params[:payload])

      response = []
      repository = payload["repository"]
      commits = payload["commits"]
      commits.reverse.each do |c|

        response << hub.push_card(  repository["owner"]["name"], repository["name"], c)
      end 
      json response
    end

    before do
      authenticate!
      Stint::Github.new(:basic_auth => {:username => settings.user_name, :password => settings.password}).add_to_team(settings.team_id, current_user) unless github_team_access? settings.team_id
      current_user
      github_team_authenticate! team_id
    end

    helpers Sinatra::ContentFor

  end
end

