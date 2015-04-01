require 'coreos'
require 'fleetctl'
require 'byebug'

class Crust
  @@config = OpenStruct.new

  attr_reader :fleet, :project, :sha, :id, :branch, :template_name, :service_filenames, :mysql_database_url, :jarvis_addr

  def initialize(options={})
    options.each{|key, val| instance_variable_set(:"@#{key}", val) }
    @fleet   = initialize_fleet
    @service_filenames = []
  end

  ## Class Methods ==============

  def self.start(options={})
    new(options).start!
  end

  def self.destroy(options={})
    new(options).destroy!
  end

  def self.start_service(file)
    new.start_service(file)
  end

  def self.get_service_status
    new.get_service_status
  end

  def self.configure
    yield(@@config)
  end

  def self.config
    @@config
  end

  def self.get_machines
    new.get_machines
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
    @service_filenames = generate_service_files
    run_service_files
  end

  def destroy!
    service_filenames_from_fleet.each{|service| fleet.destroy(service) }
  end

  def start_service(service = nil)
    service = service.presence || @service
    return unless service.present?
    result = @fleet.start(File.open(service))
    logger.info result
    result
  end

  def fleetctl_options
    Crust.config.fleetctl_options
  end

  def get_service_status
    formated_services(fleet.units_once)
  end

  def get_machines
    fleet.machines.map{|m| m.ip}
  end

  ## Private ==============
  private

  def formated_services(services)
    services = services.select{|s| s[:name].scan(/_/).count == 3}
    services.each do|service|
      app, sha, id, type = service[:name].split("_")
      type = type.split(".").first
      {app: app, sha: sha, id: id, type: type}.each do |k,v|
        service[k] = v
      end
    end
    services.each{|s| s[:id] = s[:name].split("_")[2] }
    ids = services.map{|s| s[:id]}.uniq.compact

    id_sha = {}
    ids.each do |id|
      id_sha[id] = services.select{|s| s[:id] == id}
    end
    id_sha
  end

  def service_filenames_from_fleet
    services_by_id = get_service_status
    (services_by_id[id.to_s] || []).map{|s| s[:name]}
  end

  def generate_service_files
    FileUtils.rm Dir['/tmp/*.service']
    CoreOS.convert(service_template, '/tmp', service_options)
  end

  def service_filenames_with_type
    @service_filenames.map{|f| "#{f}.service"}.reverse
  end

  def service_filenames_with_path
    service_filenames_with_type.map{|f| Dir["/tmp/#{f}"].first}
  end

  def run_service_files
    service_filenames_with_path.each do |service_file|
      start_service(service_file)
      File.try(:delete, service_file)
    end
  end

  def service_options
    {type: 'fleet', project: project, sha: sha, id: id, branch: branch, mysql_database_url: mysql_database_url, jarvis_addr: jarvis_addr}
  end

  def service_template
    service_template_hash[@template_name]
  end

  def service_template_hash
    paths = Dir[Crust.config.service_templates + '/*']
    filename = ->(path) { File.basename(path, '.erb') }
    Hash[ paths.map{ |path| [ filename.call(path), path ] } ]
  end

  def initialize_fleet
    Fleetctl.config(fleetctl_options)
    Fleetctl.new
  end

  def logger
    Crust.logger
  end
end
