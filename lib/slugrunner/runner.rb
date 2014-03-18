# coding: utf-8

require 'yaml'
require 'shellwords'
require 'tempfile'
require 'socket'
require 'timeout'
require 'open-uri'

module Slugrunner
  class Runner
    attr_accessor :bind_delay
    attr_accessor :ping_url
    attr_accessor :ping_interval
    attr_accessor :shell
    attr_accessor :extra_env

    def initialize(slug, process_type, instance_number)
      @slug = slug
      @process_type = process_type
      @ping = false
      @bind_delay = 0
      @ping_url = nil
      @ping_interval = 0
      @alive = false
      @shell = false
      @extra_env = []
      @hostname = "#{@process_type}.#{instance_number}"
    end

    def run
      Dir.mktmpdir do |tmpdir|
        logger("Scratch directory -> #{tmpdir}")
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
      notify(:setup) if @ping

      fetch_slug
      proc_command = if @shell
        '/bin/bash'
      else
        extract_command_from_procfile || extract_command_from_release
      end
      fail "Couldn't find command for process type #{@process_type}" unless proc_command

      command = prepare_env(proc_command)
      @child = fork { exec(command) }
      trap_signals

      @alive = check_port
      kill_child unless @alive

      start_ping if @ping

      Process.waitpid(@child, 0)

      @alive = false
      notify(:stop) if @ping
    end

    def check_port
      port = (ENV['PORT'] || '0').to_i

      return true if @bind_delay == 0 || port == 0

      start_ts = Time.now
      stop_ts = start_ts.to_i + @bind_delay
      while Time.now.to_i < stop_ts
        return true if is_port_open?(port)
      end

      logger("Port hasn't been open after #{@bind_delay} seconds.")
      false
    end

    def start_ping
      return unless @alive

      notify(:start)

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
        logger("Killing process #{@child} with SIGKILL.")
        Process.kill('KILL', @child)
      end
    end

    def notify(state)
      # these are fire and forget for now
      ap = "state=#{state}&hostname=#{@hostname}"
      if @ping_url =~ /\?/
        open("#{@ping_url}&#{ap}")
      else
        open("#{@ping_url}?#{ap}")
      end
    rescue => e
      logger("Failed to notify #{@ping_url}: #{e}")
    end

    def logger(str)
      puts("[slugrunner] #{str}")
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
        `tar zx -C #{@slug_dir} -f #{@slug}`
      end

      fail 'Failed to decompress slug' if $?.exitstatus != 0
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

    def prepare_env(cmd)
      blob = <<-eos
      exec env - bash -c '
      cd #{@slug_dir}
      export HOME=#{@slug_dir}
      export APP_DIR=#{@slug_dir}
      export HOSTNAME="#{@hostname}"
      export SLUGRUNNER=1
      export SLUG_ENV=1
      PORT=#{ENV['PORT'] || 0}
      for file in .profile.d/*; do source $file; done
      eos

      @extra_env.each do |e|
        pair = e.split(/=/, 2)
        next unless pair.length == 2
        escaped = pair.map { |n| Shellwords.escape(n) }
        blob += "export #{escaped[0]}=#{escaped[1]}\n"
      end

      blob += "exec #{cmd}'"
      blob
    end
  end
end
