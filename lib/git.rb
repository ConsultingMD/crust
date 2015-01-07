class Git

  attr_accessor :owner, :repo, :directory, :options

  def initialize(owner, repo, directory, options = {})
    @owner, @repo, @options = owner, repo, options
    @directory = File.expand_path(directory)
    @runner    = Runner.new(directory)
  end

  def clone!
    run! "git clone git@github.com:#{owner}/#{repo}.git"
  end

  def checkout(name, type = :file)
    case type
      when :file
        fetch_file(name)
      when :branch
        run! "git checkout #{name}"
    end
  end

  private

  def run! cmd
    @runner.in_dir do |r|
      r.run cmd
    end
  end

  def fetch_file(file)
    token = option(:token)
    cmd   = fetch_file_cmd % [token, owner, repo, file]
    run! cmd
  end

  def fetch_file_cmd
    'curl -H "Authorization: token %s" -H "Accept: application/vnd.github.v3.raw" --remote-name --location https://api.github.com/repos/%s/%s/contents/%s'
  end

  def option(key)
    return if key.nil? || key.empty?
    options[key.to_s] || options[key.to_sym]
  end

  class Runner
    attr_reader :directory

    def initialize(directory)
      @directory = File.expand_path(directory)
      make_dir!
    end

    def in_dir
      cd
      yield self
    end

    def run(cmd)
      system cmd
    end

    def cd(dir = nil)
      dir ||= directory
      run "cd #{dir}"
    end

    private

    def make_dir!
      run "mkdir -p #{directory}"
    end

  end
end