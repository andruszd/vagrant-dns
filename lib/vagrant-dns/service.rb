require 'daemons'

module VagrantDNS
  class Service
    attr_accessor :tmp_path

    def initialize(tmp_path)
      self.tmp_path = tmp_path
    end

    def start!(opts = {})
      run_options = {
        :ARGV => ["start"],
        :ontop => opts[:ontop]
      }.merge!(runopts)
      run!(run_options)
    end

    def stop!
      run_options = {:ARGV => ["stop"]}.merge(runopts)
      run!(run_options)
    end

    def status!
      run_options = {:ARGV => ["status"]}.merge(runopts)
      run!(run_options)
    end

    def run!(run_options)
      Daemons.run_proc("vagrant-dns", run_options) do
        require 'rubydns'
        require 'async/dns/system'

        registry = Registry.new(tmp_path).to_hash
        std_resolver = RubyDNS::Resolver.new(Async::DNS::System.nameservers)
        ttl = VagrantDNS::Config.ttl

        RubyDNS::run_server(VagrantDNS::Config.listen) do
          registry.each do |pattern, ip|
            match(pattern, Resolv::DNS::Resource::IN::A) do |transaction, match_data|
              transaction.respond!(ip, ttl: ttl)
            end
          end

          otherwise do |transaction|
            transaction.passthrough!(std_resolver) do |reply, reply_name|
              puts reply
              puts reply_name
            end
          end
        end
      end
    end

    def restart!(start_opts = {})
      stop!
      start!(start_opts)
    end

    def show_config
      registry = Registry.new(tmp_path).to_hash

      if registry.any?
        registry.each do |pattern, ip|
          puts format("%s => %s", pattern.inspect, ip)
        end
      else
        puts "Configuration missing or empty."
      end
    end

    def runopts
      daemon_dir = File.join(tmp_path, "daemon")
      {
        :dir_mode   => :normal,
        :dir        => daemon_dir,
        :log_output => true,
        :log_dir    => daemon_dir
     }
    end
  end
end
