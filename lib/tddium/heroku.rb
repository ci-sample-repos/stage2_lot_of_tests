# Copyright (c) 2011, 2012 Solano Labs All Rights Reserved

require 'timeout'

module Tddium
  class HerokuConfig
    class HerokuError < RuntimeError; end
    class HerokuNotFound < HerokuError; end
    class TddiumNotAdded < HerokuError; end
    class InvalidFormat < HerokuError; end
    class NotLoggedIn < HerokuError; end
    class AppNotFound < HerokuError; end

    REQUIRED_KEYS = %w{TDDIUM_API_KEY TDDIUM_USER_NAME}
    def self.read_config(app=nil)
      config = {}

      command = base_command = ENV['TDDIUM_HEROKU_COMMAND'] || 'heroku'
      command += " config -s"
      command += " --app #{app}" if app

      begin
        output = `#{command} < /dev/null 2>&1`
      rescue Errno::ENOENT
        raise HerokuNotFound
      end
      raise HerokuNotFound if output =~ /#{base_command}: not found/
      raise AppNotFound if output =~ /App not found/
      raise InvalidFormat if output.length == 0
      raise NotLoggedIn if output =~ /Heroku credentials/

      output.lines.each do |line|
        line.chomp!
        k, v = line.split('=')
        if v && v.length > 0
          v = v.chomp('"').reverse.chomp('"').reverse
          if k =~ /^TDDIUM_/
            k.sub!("TDDIUM_STAGE", "TDDIUM")
            config[k] = v
          end
        end
      end
      raise TddiumNotAdded if config.keys.length == 0
      raise InvalidFormat if REQUIRED_KEYS.inject(false) {|missing, x| missing || !config[x]}
      config
    end
  end
end