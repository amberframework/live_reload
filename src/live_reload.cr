require "./client_reload"
require "http"

module LiveReload
  VERSION = "0.1.0"

  class Handler
    include HTTP::Handler
    CONTENT_TYPE_HEADER = "Content-Type"

    def initialize(
      logger : Environment::Logger = Amber.settings.logger,
      @env : Environment::Env = Amber.env
    )
      LiveReload::Client.run(
        watch_config = {
          "commands" => [""],
          "files"    => ["public/**/*"],
        },
        logger
      )
    end

    def initialize(
      config : Hash(String, Array(String)),
      logger : Environment::Logger = Amber.settings.logger,
      @env : Environment::Env = Amber.env
    )
      LiveReload::Client.run(config, logger)
    end

    def call(context : HTTP::Server::Context)
      if @env.development? && context.request.headers[CONTENT_TYPE_HEADER]?.to_s.downcase == "text/html"
        context.response.headers["Client-Reload"] = %(true)
      end
      call_next(context)
    end
  end
end
