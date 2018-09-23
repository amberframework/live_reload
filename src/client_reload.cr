require "logger"
require "./file_watcher"

module LiveReload
  struct Client
    CLI_IO    = ::Process::Redirect::Inherit
    SESSIONS  = [] of HTTP::WebSocket
    PROCESSES = [] of Process

    @file_watcher = FileWatcher.new
    @app_running = false

    getter commands : Array(String),
      files : Array(String),
      logger : Environment::Logger

    def self.run(watch_config : Hash(String, Array(String)), logger : Environment::Logger)
      new(watch_config, logger).run
    end

    def initialize(watch_config : Hash(String, Array(String)), @logger)
      @commands = watch_config["commands"]
      @files = watch_config["files"]

      at_exit do
        kill_client_processes
      end
    end

    def run
      run_watcher
    rescue ex
      error "Error in watch configuration. #{ex.message}"
      exit 1
    end

    private def run_watcher
      if files.empty?
        run_commands
      else
        spawn watcher
      end
      create_reload_server
    rescue ex
      error "Error in watch configuration. #{ex.message}"
      exit 1
    end

    private def watcher
      loop do
        scan_files
        @app_running = true
        sleep 1
      end
    end

    # Todo : Extract websocket dependency
    private def create_reload_server
      Amber::WebSockets::Server::Handler.new "/client-reload" do |session|
        SESSIONS << session
        session.on_close do
          SESSIONS.delete session
        end
      end
    end

    def scan_files
      file_counter = 0
      @file_watcher.scan_files(files) do |file|
        if @app_running
          debug "File changed: #{file}"
        end
        file_counter += 1
        check_file(file)
      end
      if file_counter > 0
        debug "Watching #{file_counter} client files..."
        kill_client_processes
        run_commands
      end
    end

    private def check_file(file)
      case file
      when .ends_with? ".css"
        reload_clients(msg: "refreshcss")
      else
        reload_clients(msg: "reload")
      end
    end

    private def reload_clients(msg)
      SESSIONS.each do |session|
        session.@ws.send msg
      end
    end

    private def run_commands
      commands.each do |command|
        PROCESSES << run_process(command)
      end
    end

    private def kill_client_processes
      PROCESSES.each do |process|
        process.kill unless process.terminated?
        PROCESSES.delete(process)
      end
    end

    private def debug(msg)
      logger.debug msg, "Watcher", :light_gray
    end

    private def error(msg)
      logger.error msg, "Watcher", :red
    end

    private def warn(msg)
      logger.warn msg, "Watcher", :yellow
    end

    private def run_process(command, shell = true, input = CLI_IO, output = CLI_IO, error = CLI_IO)
      ::Process.new(command, shell: shell, input: input, output: output, error: error)
    end
  end
end
