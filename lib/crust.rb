#!/usr/bin/env ruby
require 'coreos'
require 'fleetctl'
require 'byebug'

class Crust

  @@config = OpenStruct.new
  attr_accessor :fleet

  attr_reader :fleet, :project, :sha

  def initialize(options={})
    @project = options[:project]
    @sha     = options[:sha]
    @service = options[:service]
    @fleet   = initialize_fleet
  end

  ## Class Methods ==============

  def self.start(project, sha)
    new(project: project, sha: sha).start!
  end

  def self.destroy(project, sha)
    new(project: project, sha: sha).destroy!
  end

  def self.start_service(file)
    new.start_service(file)
  end

  def self.configure
    yield(@@config)
  end

  def self.config
    @@config
  end

  def self.logger
    logger = @@config.logger
    @@config.logger =
      case logger
        when String then Logger.new(logger)
        when Logger then logger
        else Logger.new('/tmp/crust.log')
      end
  end

  ## Public ==============

  def start!
    generate_service_files
    run_service_files
  end

  def destroy!
    service_files.each{|service| fleet.destroy(service) }
  end

  def start_service(service = nil)
    service = service.presence || @service
    return unless service.present?
    result = @fleet.start(File.open(service))
    logger.info result
    result
  end

  def fleet_host
    Crust.config.host
  end

  def ssh_options
    Crust.config.ssh
  end

  def get_services
    fleet.unit_names
  end

  ## Private ==============

  private

  def service_files
    %w[app mysql].map{|type| "#{project}_#{sha}_#{type}.1.service" }
  end

  def generate_service_files
    FileUtils.rm Dir['/tmp/*.service']
    CoreOS.convert(service_template, '/tmp', service_options)
  end

  def run_service_files
    service_files = Dir['/tmp/*mysql.1.service'] + Dir['/tmp/*app.1.service']
    service_files.each do |service_file|
      start_service(service_file)
      File.delete(service_file)
    end
  end

  def service_options
    {type: 'fleet', project: project, sha: sha}
  end

  def service_template
    Crust.config.service_template
  end

  def initialize_fleet
    Fleetctl.config(fleet_host: fleet_host, ssh_options: ssh_options)
    Fleetctl.new
  end

  def logger
    Crust.logger
  end
end
