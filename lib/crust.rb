#!/usr/bin/env ruby
require 'fig2coreos'
require 'fleetctl'
require 'byebug'

class Crust

  def initialize
    Fleetctl.config( fleet_host: 'coreos.test.grandrounds.com' )
    @fleet = Fleetctl.new
  end

  def run_build(project, sha)
    generate_service_files(project, sha)
    start_generated_files
  end

  def start_logspout
    from_here = "/service_files/logspout.service"
    filename = (File.dirname __FILE__) + from_here
    start_service_file(filename)
  end

  private

  def generate_service_files(project, sha)
    ENV["SHA"] = sha
    Fig2CoreOS.convert(project, "projects/#{project}.erb", 'tmp_service_files', {type: "fleet", skip_discovery_file: true})
  end

  def start_service_file(filename)
    puts @fleet.start File.open(filename)
  end

  def start_generated_files
    service_files = Dir["tmp_service_files/*.service"]
    service_files.each do |service_file|
      start_service_file(service_file)
      File.delete(service_file)
    end
  end

end

#Crust.new.start_logspout
#Crust.new.run_build('tp', 'c74f5c1')
