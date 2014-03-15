require 'trollop'

module Slugrunner
  module CLI
    module_function

    def run
      opts = Trollop::options do
        opt :slug, 'Slug file', type: :string
        opt :worker, 'Worker type', type: :string, default: 'web'
        opt :instance, 'Instance number', default: 1
        opt :delayed_bind, 'Port bind allowance', default: 0
        opt :ping, 'Notify state updates', type: :string
        opt :ping_interval, 'Update interval in seconds', default: 30
        opt :env, 'Append to environment', type: :strings
        opt :bash, 'Run interactive shell', default: false
      end

      Trollop::die :slug, "must be present" if opts[:slug].nil?
      Trollop::die :worker, "must be present" if opts[:worker].nil?

      runner = Slugrunner::Runner.new(opts[:slug], opts[:worker], opts[:instance])

      unless opts[:ping].nil?
        runner.ping_url = opts[:ping]
        runner.ping_interval = opts[:ping_interval]
      end

      runner.shell = opts[:bash]
      runner.extra_env = opts[:env] if opts[:env]

      if opts[:delayed_bind] > 0
        runner.bind_delay = opts[:delayed_bind]
      end

      # will setup/forward signals and block until stopped
      exit(runner.run)
    end
  end
end
