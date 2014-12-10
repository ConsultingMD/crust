Crust.configure do |config|
  config.host   = ENV['COREOS_HOST']
  config.ssh    = {keys: '/home/ubuntu/.ssh/id_rsa'}
end
