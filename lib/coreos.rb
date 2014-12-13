class CoreOS

  def self.convert(service, out_path, options={})
    CoreOS.new(service, out_path, options)
  end

  def initialize(service, out_path, options={})
    @services = load_yml(service.to_s, options)
    @out_path = File.expand_path(out_path.to_s)
    @options  = options
    load_templates
    setup_directory_structure
    create_service_files
  end

  private

  def create_service_files
    @services.each do |name, service|

      locals = create_local_vars(name, service)
      file_name = path_to("#{name}.service")

      File.open(file_name, 'w') do |file|
        file << template(:service, locals)
      end

    end
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
    ports   = (service[:ports]       || []).map{|port| "-p #{port}"}
    volumes = (service[:volumes]     || []).map{|volume| "-v #{volume}"}
    links   = (service[:links]       || []).map{|link| "--link #{link}:mysql"}
    envs    = (service[:environment] || []).map{|name, value| "-e \"#{name}=#{value}\"" }
    after   = (service[:links].present? ? "#{service[:links].last}" : 'docker')
    xfleet   = ( service[:xfleet] ? true : false )
    machineof   = machine_of(service)

    {
      service_name: name,
      volumes:      volumes.join(' '),
      after:        after,
      links:        links.join(' '),
      envs:         envs.join(' '),
      ports:        ports.join(' '),
      image:        image,
      xfleet:       xfleet,
      machine_of:   machineof
    }
  end

  def machine_of(service)
    if service[:xfleet] and service[:xfleet][:machineof]
      "Machineof=#{service[:xfleet][:machineof]}"
    else
      ""
    end
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
    project, sha, id = [:project, :sha, :id].map{|i| options[i]}
    build_name = "#{project}_#{sha}_#{id}"
    read_token = ENV['GITHUB_READ_TOKEN']
    YAML.load(ERB.new(File.read(filename.to_s)).result(binding))
  end

end
