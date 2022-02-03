# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'
require 'juwelier'
Juwelier::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "raka"
  gem.required_ruby_version = '>= 2.3.0'
  gem.homepage = "http://github.com/yarray/raka"
  gem.license = "MIT"
  gem.summary = %Q{Rake for data}
  gem.description = %Q{An extensible, concise and light weight DSL on Rake to automate data processing tasks}
  gem.email = "08to09@gmail.com"
  gem.authors = ["yarray"]
  gem.files = Dir['README.md', 'VERSION', 'lib/**/*']

  # dependencies defined in Gemfile
end
Juwelier::RubygemsDotOrgTasks.new

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "raka #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
