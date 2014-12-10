class CoreOS

  def self.convert(service_file, output_dir, options={})
    CoreOS.new(service_file, output_dir, options)
  end

  def initialize(service_file, output_dir, options={})
    @app_name   = app_name
    @services   = load_yml(service_file.to_s, options)
    @output_dir = File.expand_path(output_dir.to_s)
    @options    = options
    load_templates
    setup_directory_structure
    create_service_files
  end

  private

  def create_service_files
    @services.each do |service_name, service|

      locals = create_local_vars(service_name, service)
      file_name = path_to("#{service_name}.1.service")

      File.open(file_name, 'w') do |file|
        file << template(:service, locals)
      end

    end
  end

  # This assumes that all attempted files other than .erb can be parsed as yaml
  def load_yml(filename, options={})
    case File.extname(filename)
      when '.erb'
        parse_erb(filename, options)
      else
        YAML.load_file(filename)
    end
  end

  def load_templates
    templates = YAML.load_file(File.join(File.dirname(__FILE__), 'templates.yml'))
    I18n.backend.store_translations(:en, templates)
  end

  def template(name=:service, options={})
    I18n.backend.translate(:en, name, options)
  end

  def create_local_vars(service_name, service)
    image   = service['image']
    ports   = (service['ports']       || []).map{|port| "-p #{port}"}
    volumes = (service['volumes']     || []).map{|volume| "-v #{volume}"}
    links   = (service['links']       || []).map{|link| "--link #{link}_1:mysql"}
    envs    = (service['environment'] || []).map{|env_name, env_value| "-e \"#{env_name}=#{env_value}\"" }
    after   = (service['links'].present? ? "#{service['links'].last}.1" : 'docker')
    {
      service_name: service_name,
      volumes:      volumes.join(' '),
      after:        after,
      links:        links.join(' '),
      envs:         envs.join(' '),
      ports:        ports.join(' '),
      image:        image
    }
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
    File.join(@output_dir, *args)
  end

  def parse_erb(filename, options)
    project = options[:project]
    sha = options[:sha]
    project_sha = "#{project}_#{sha}"
    read_token = ENV['GITHUB_READ_TOKEN']
    YAML.load(ERB.new(File.read(filename.to_s)).result(binding))
  end
end
