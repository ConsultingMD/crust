class CoreOS

  def self.convert(app_name, fig_file, output_dir, options={})
    CoreOS.new(app_name, fig_file, output_dir, options)
  end

  def initialize(app_name, fig_file, output_dir, options={})
    @app_name = app_name
    @fig = load_yml(fig_file.to_s, options)
    @output_dir = File.expand_path(output_dir.to_s)
    @vagrant = (options[:type] == 'vagrant')
    @options = options
    @templates = load_templates

    # clean and setup directory structure
    FileUtils.rm_rf(Dir[File.join(@output_dir, '*.service')])
    FileUtils.rm_rf(File.join(@output_dir, 'media'))
    FileUtils.rm_rf(File.join(@output_dir, 'setup-coreos.sh'))
    FileUtils.rm_rf(File.join(@output_dir, 'Vagrantfile'))

    if @vagrant
      FileUtils.mkdir_p(File.join(@output_dir, 'media', 'state', 'units'))
      create_vagrant_file
    end

    create_service_files
  end

  #This assumes that all attempted files other than .erb can be parsed as yaml
  def load_yml(filename, options={})
    project = options[:project]
    sha = options[:sha]
    project_sha = "#{project}_#{sha}"
    read_token = ENV['GITHUB_READ_TOKEN']
    case File.extname(filename.to_s)
      when '.erb'
        YAML.load(ERB.new(File.read(filename.to_s)).result(binding))
      else
        YAML.load_file(filename.to_s)
    end
  end

  def load_templates
    templates = YAML.load_file(File.join(File.dirname(__FILE__), 'templates.yml'))
    I18n.backend.store_translations(:en, templates)
  end

  def template(name=:service, options={})
    I18n.backend.translate(:en, name, options)
  end

  def create_service_files
    @fig.each do |service_name, service|
      image   = service['image']
      ports   = (service['ports']       || []).map{|port| "-p #{port}"}
      volumes = (service['volumes']     || []).map{|volume| "-v #{volume}"}
      links   = (service['links']       || []).map{|link| "--link #{link}_1:mysql"}
      envs    = (service['environment'] || []).map{|env_name, env_value| "-e \"#{env_name}=#{env_value}\"" }

      after = if service['links']
                "#{service['links'].last}.1"
              else
                "docker"
              end

      if @vagrant
        base_path = File.join(@output_dir, "media", "state", "units")
      else
        base_path = @output_dir
      end

      File.open(File.join(base_path, "#{service_name}.1.service") , "w") do |file|
        # locals = {
        #   service_name: service_name,
        #   volumes: volumes,
        #   after: after,
        #   links: links,
        #   envs:  envs,
        #   ports: ports,
        #   image: image
        # }
        # input = template(:service, locals)
        # byebug
        # file << input
        file << <<-eof
[Unit]
Description=Run #{service_name}_1
After=#{after}.service
Requires=#{after}.service

[Service]
Restart=always
RestartSec=10s
ExecStartPre=/usr/bin/docker ps -a -q | xargs docker rm
ExecStart=/usr/bin/docker run -rm -name #{service_name}_1 #{volumes.join(" ")} #{links.join(" ")} #{envs.join(" ")} #{ports.join(" ")} #{image}
ExecStartPost=/usr/bin/docker ps -a -q | xargs docker rm
ExecStop=/usr/bin/docker kill #{service_name}_1
ExecStopPost=/usr/bin/docker ps -a -q | xargs docker rm

[Install]
WantedBy=local.target
        eof
      end

      unless @options[:skip_discovery_file]
        File.open(File.join(base_path, "#{service_name}-discovery.1.service"), "w") do |file|
          port = %{\\"port\\": #{service["ports"].first.to_s.split(':').first}, } if service['ports'].to_a.size > 0
          # locals = {service_name: service_name, port: port}
          # input = template(:discovery, locals)
          # byebug
          # file << input

          file << <<-eof
  [Unit]
  Description=Announce #{service_name}_1
  BindsTo=#{service_name}.1.service

  [Service]
  ExecStart=/bin/sh -c "while true; do etcdctl set /services/#{service_name}/#{service_name}_1 '{ \\"host\\": \\"%H\\", #{port}\\"version\\": \\"52c7248a14\\" }' --ttl 60;sleep 45;done"
  ExecStop=/usr/bin/etcdctl rm /services/#{service_name}/#{service_name}_1

  [X-Fleet]
  X-ConditionMachineOf=#{service_name}.1.service
          eof
        end
      end
    end
  end


end