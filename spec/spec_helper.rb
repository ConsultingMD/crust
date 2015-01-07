if defined?(Crust)
  Crust.configure do |config|
    config.host   = ENV['COREOS_HOST']
    config.ssh    = {keys: '/home/ubuntu/.ssh/id_rsa'}
  end
end

if defined?(Git)
  class Git
    def run! cmd
      cmd
    end
    class Runner
      def run cmd
        cmd
      end
    end
  end
end