#!/usr/bin/env ruby
require 'fig2coreos'
require 'fleetctl'
require 'byebug'

class Crust

  @@config = OpenStruct.new

  def initialize
    Fleetctl.config( fleet_host: Crust.config.host )
    @fleet = Fleetctl.new
  end

  ## Class Methods ==============

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

  def run_build(project, sha)
    generate_service_files(project, sha)
    start_generated_files
  end

  def start_service_file(filename)
    result = @fleet.start(File.open(filename))
    Crust.logger.info result
  end

  ## Private ==============

  private

  def generate_service_files(project, sha)
    FileUtils.rm Dir['/tmp/*.service']
    ENV['SHA'] = sha
    Fig2CoreOS.convert(
      project,
      template_path("#{project}.erb"),
      '/tmp',
      type: 'fleet', skip_discovery_file: true
    )
  end

  def start_generated_files
    service_files = Dir['/tmp/*mysql.1.service'] + Dir['/tmp/*app.1.service']
    service_files.each do |service_file|
      start_service_file(service_file)
      File.delete(service_file)
    end
  end

  def template_path(file=nil)
    path = "#{Crust.config.project_template_directory}/"
    path << file if file.present?
    path
  end

end

#Crust.new.start_logspout
#Crust.new.run_build('tp', 'c74f5c1')
