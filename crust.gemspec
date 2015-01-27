# coding: utf-8
lib = File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'crust'
  s.version     = '0.0.16'
  s.date        = '2014-12-09'
  s.summary     = 'Works with CoreOS'
  s.description = 'A simple coreos gem'
  s.authors     = ['Ozzie Gooen']
  s.email       = 'ozzie@grandrounds.com'
  s.files       = ['lib/crust.rb', 'lib/coreos.rb', 'lib/templates.yml']
  s.homepage    = 'http://rubygems.org/gems/crust'
  s.license     = 'MIT'
end
