# coding: utf-8

require 'faraday'
require 'tempfile'
require 'socket'
require 'timeout'

module Slugrunner
  class Runner
    attr_accessor :bind_delay
    attr_accessor :ping_url
    attr_accessor :ping_interval

    def initialize(slug, process_type)
      @slug = slug
      @process_type = process_type
      @ping = false
      @bind_delay = 0
      @ping_url = nil
      @ping_interval = 0
      @alive = false
      @slug_file = nil
    end

    def run
      Dir.mktmpdir do |tmpdir|
        @slug_dir = tmpdir
        @ping = true if !@ping_url.nil? && @ping_interval > 0
        download_and_run
        return 0
      end
    rescue => e
      logger("Error: #{e}")
      return 1
    end

    private

    def download_and_run
      fetch_slug
      command = extract_command_from_procfile || extract_command_from_release
      fail "Couldn't find command for process type #{@process_type}" unless command

      notify(:start) if @ping

      logger("Running #{@slug}")
      @child = fork { exec(command) }
      trap_signals

      kill_child unless check_port

      start_ping if @ping

      Process.wait

      if @ping
        @alive = false
        notify(:stop)
      end
    end

    def check_port
      port = (ENV['PORT'] || '0').to_i

      if port < 1
        logger("Port #{port} cannot be checked. Skipping...")
        return true
      end

      logger("Checking if port is active")
      start_ts = Time.now
      stop_ts = start_ts.to_i + @bind_delay
      while Time.now.to_i < stop_ts
        if is_port_open?(port)
          logger("Port opened in #{Time.now - start_ts} seconds")
          return true
        end
      end

      logger("Port hasn't been open after #{@bind_delay} seconds.") 
      return false
    end

    def start_ping
      @alive = true
      Thread.new do
        while @alive
          sleep(@ping_interval)
          notify(:update)
        end
      end
    end

    def trap_signals
      %w{INT HUP TERM QUIT}.each do |sig|
        Signal.trap(sig) do
          logger("Forwarding #{sig} to #{@child}")
          Process.kill(sig, @child)
        end
      end
    end

    def kill_child
      if @child
        logger("Killing process #{@child} with SIGTERM.")
        Process.kill('TERM', @child)
      end
    end

    def notify(state)
      logger("Process is going #{state}")
    end

    def logger(str)
      puts(str)
    end

    def is_port_open?(port)
      Timeout::timeout(1) do
        begin
          s = TCPSocket.new('localhost', port)
          s.close
          return true
        rescue
          return false
        end
      end
    rescue
      return false
    end

    def fetch_slug
      if @slug =~ /^http/
        `curl -s "#{@slug}" | tar -zxC #{@slug_dir}`
      else
        `tar zx -C #{@slug_dir} -f #{@slug_file}`
      end

      fail 'Failed to decompress slug' if $CHILD_STATUS != 0
    end

    def extract_command_from_procfile
      return nil unless File.exists?("#{@slug_dir}/Procfile")

      procfile = YAML.load_file("#{@slug_dir}/Procfile")
      return procfile[@process_type] if procfile.key?(@process_type)
    end

    def extract_command_from_release
      return nil unless File.exists?("#{@slug_dir}/.release")

      release = YAML.load_file("#{@slug_dir}/.release")
      return release['default_process_types'][@process_type] if release['default_process_types'].key?(@process_type)
    end
  end
end
