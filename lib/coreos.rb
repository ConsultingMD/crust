class CoreOS

  attr_reader :service_filenames

  def self.convert(service, out_path, options={})
    CoreOS.new(service, out_path, options).service_filenames
  end

  def initialize(service, out_path, options={})
    @options  = options
    @services = load_yml(service.to_s, options)
    @out_path = File.expand_path(out_path.to_s)
    load_templates
    setup_directory_structure
    @service_filenames = create_service_files
  end

  private

  def create_service_files
    @services.each do |name, service|

      locals = create_local_vars(name, service)
      file_name = path_to(service_file(name))

      File.open(file_name, 'w') do |file|
        file << template(:service, locals)
      end

    end
    @services.keys.map{|k| service_name(k)}
  end

  # This assumes that all attempted files other than .erb can be parsed as yaml
  def load_yml(template, options={})
    case File.extname(template)
      when '.erb'
        parse_erb(template, options)
      else
        YAML.load_file(template)
    end
  end

  def load_templates
    templates = YAML.load_file(File.join(File.dirname(__FILE__), 'templates.yml'))
    I18n.backend.store_translations(:en, templates)
  end

  def template(name=:service, options={})
    I18n.backend.translate(:en, name, options)
  end

  def create_local_vars(name, service)
    service = service.symbolize_keys
    service[:xfleet].symbolize_keys! if service[:xfleet]

    image   = service[:image]
    command = service[:command].present? ? "/bin/bash -c '#{service[:command]}'" : ''
    ports   = (service[:ports]       || []).map{|port| "-p #{port}"}
    volumes = (service[:volumes]     || []).map{|volume| "-v #{volume}"}

    #This assumes that the container names end with their app name
    links   = (service[:links]       || []).map{|link| "--link #{service_name(link)}:#{link}"}
    envs    = (service[:environment] || []).map{|name, value| "-e \"#{name}=#{value}\"" }
    after   = (service[:links].present? ? "#{service_name(service[:links].last)}" : 'docker')
    xfleet  = service[:xfleet].present?
    machine = machine_of(service)

    {
      service_name: service_name(name),
      volumes:      volumes.join(' '),
      after:        after,
      links:        links.join(' '),
      envs:         envs.join(' '),
      ports:        ports.join(' '),
      image:        image,
      xfleet:       xfleet,
      command:      command,
      machine_of:   machine
    }
  end

  def machine_of(service)
    name = service[:xfleet][:machineof] rescue nil
    name.present? ? "MachineOf=#{service_file(name)}" : ''
  end

  def get_port(service)
    if service['ports'].present?
      port = service['ports'].first.to_s.split(':').first
      %{\\"port\\": #{port}, }
    end
  end

  def setup_directory_structure
    FileUtils.rm_rf Dir[path_to('*.service')]

    %w[media setup-coreos.sh].each do |file|
      FileUtils.rm_rf path_to(file)
    end
  end

  def path_to(*args)
    File.join(@out_path, *args)
  end

  def parse_erb(filename, options)
    project, sha, id, branch, mysql_database_url, jarvis_addr = [:project, :sha, :id, :branch, :mysql_database_url, :jarvis_addr].map{|key| options[key] }
    build_name = "#{project}_#{sha}_#{id}"
    read_token = ENV['GITHUB_READ_TOKEN']
    YAML.load(ERB.new(File.read(filename.to_s)).result(binding))
  end

  def service_name(service)
    build_name + "_" + service
  end

  def service_file(service)
    service_name(service) + ".service"
  end

  def build_name
    project, sha, id = [:project, :sha, :id].map{|i| @options[i]}
    "#{project}_#{sha}_#{id}"
  end

end
