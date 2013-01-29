# Copyright (c) 2011, 2012 Solano Labs All Rights Reserved

module Tddium
  class TddiumCli < Thor
    desc "heroku", "Connect Heroku account with Tddium"
    method_option :email, :type => :string, :default => nil
    method_option :password, :type => :string, :default => nil
    method_option :ssh_key_file, :type => :string, :default => nil
    method_option :app, :type => :string, :default => nil
    def heroku
      user_details = tddium_setup(:login=>false)

      if user_details then
        # User is already logged in, so just display the info
        show_user_details(user_details)
      else
        begin
          heroku_config = Tddium::HerokuConfig.read_config(options[:app])
          # User has logged in to heroku, and TDDIUM environment variables are
          # present
          handle_heroku_user(options, heroku_config)
        rescue Tddium::HerokuConfig::HerokuNotFound
          gemlist = `gem list heroku`
          msg = Text::Error::Heroku::NOT_FOUND % gemlist
          exit_failure msg
        rescue Tddium::HerokuConfig::TddiumNotAdded
          exit_failure Text::Error::Heroku::NOT_ADDED
        rescue Tddium::HerokuConfig::InvalidFormat
          exit_failure Text::Error::Heroku::INVALID_FORMAT
        rescue Tddium::HerokuConfig::NotLoggedIn
          exit_failure Text::Error::Heroku::NOT_LOGGED_IN
        rescue Tddium::HerokuConfig::AppNotFound
          exit_failure Text::Error::Heroku::APP_NOT_FOUND % options[:app]
        end
      end
    end

    private

      def handle_heroku_user(options, heroku_config)
        api_key = heroku_config['TDDIUM_API_KEY']
        user = @tddium_api.get_user(api_key)
        exit_failure Text::Error::HEROKU_MISCONFIGURED % "Unrecognized user" unless user
        say Text::Process::HEROKU_WELCOME % user["email"]

        if user["heroku_needs_activation"] == true
          say Text::Process::HEROKU_ACTIVATE
          params = @tddium_api.get_user_credentials(:email => heroku_config['TDDIUM_USER_NAME'])
          params.delete(:email)
          params[:password_confirmation] = HighLine.ask(Text::Prompt::PASSWORD_CONFIRMATION) { |q| q.echo = "*" }
          begin
            params[:user_ssh_key] = prompt_ssh_key(options[:ssh_key])
          rescue TddiumError => e
            exit_failure e.message
          end

          # Prompt for accepting terms
          say Text::Process::TERMS_OF_SERVICE
          license_accepted = ask(Text::Prompt::LICENSE_AGREEMENT)
          exit_failure unless license_accepted.downcase == Text::Prompt::Response::AGREE_TO_LICENSE.downcase

          begin
            user_id = user["id"]
            result = @tddium_api.update_user(user_id, {:user=>params, :heroku_activation=>true}, api_key)
          rescue TddiumClient::Error::API => e
            exit_failure Text::Error::HEROKU_MISCONFIGURED % e
          rescue TddiumClient::Error::Base => e
            exit_failure Text::Error::HEROKU_MISCONFIGURED % e
          end
        end

        @api_config.set_api_key(user["api_key"], user["email"])
        @api_config.write_config
        say Text::Status::HEROKU_CONFIG
      end
  end
end