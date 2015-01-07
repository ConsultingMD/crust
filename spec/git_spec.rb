require_relative '../lib/git'
require 'spec_helper'

describe Git do
  let(:owner){ 'ConsultingMD' }
  let(:repo){ 'crust' }
  let(:directory){ '/tmp/crust' }
  let(:options){ {token: 'ABC123'} }
  let(:token) { options[:token] }
  let(:git){ Git.new(owner, repo, directory, options) }
  let(:runner){ git.instance_variable_get(:'@runner') }
  let(:fetch_file_str){ 'curl -H "Authorization: token %s" -H "Accept: application/vnd.github.v3.raw" --remote-name --location https://api.github.com/repos/%s/%s/contents/%s' }
  let(:fetch_file_cmd) do
    fetch_file_str % [token, owner, repo, 'test.sh']
  end

  context 'initializing' do
    it('stores owner')    { expect(git.owner).to eq(owner)         }
    it('stores repo')     { expect(git.repo).to eq(repo)           }
    it('stores directory'){ expect(git.directory).to eq(directory) }
    it('stores options')  { expect(git.options).to eq(options)     }

    it 'creates a runner with directory' do
      expect(runner).to_not be_nil
      expect(runner.directory).to eq(directory)
    end
  end

  context 'running' do
    it 'fetches options with string or symbol key' do
      expect(git.send(:option, :token)).to eq(token)
      expect(git.send(:option, 'token')).to eq(token)
    end

    it 'builds correct fetch file command' do
      expect(git.send(:fetch_file, 'test.sh')).to eq(fetch_file_cmd)
    end
  end

  describe 'clone' do
    it 'clones the github repo matching the args' do
      expect(git.clone!).to eq("git clone git@github.com:#{owner}/#{repo}.git")
    end
  end

  describe 'checkout' do
    context 'file' do
      it 'fetches the file from the repo only' do
        expect(git.checkout('test.sh')).to eq(fetch_file_cmd)
      end
    end

    context 'branch' do
      it 'checks out the specified branch into the cloned repo' do
        expect(git.checkout('mock-branch', :branch)).to eq('git checkout mock-branch')
      end
    end
  end

  describe 'Runner' do
    context 'initializing' do
      it 'makes the directory passed' do
        expect(runner.send(:make_dir!)).to eq("mkdir -p #{directory}")
      end
    end
    context 'running' do
      it 'changes to default directory when none provided' do
        expect(runner.cd).to eq("cd #{directory}")
      end

      it 'changes to provided directory' do
        expect(runner.cd('/tmp/new/dir')).to eq("cd /tmp/new/dir")
      end
      
    end
  end
end
