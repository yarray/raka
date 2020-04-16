require 'fileutils'
require "test/unit"
require 'rake'
require 'raka'

class TestContext
  def initialize
    @tests = []
  end
  
  def add_test(&block)
    @tests.push block
  end

  def tests
    return @tests
  end
end


class RakaTest < Test::Unit::TestCase
  rake = Rake.application
  rake.init
  all_samples = Dir.glob("**/*.raka")
  # all_samples = ['capture/group.raka']
  all_samples.each do |path|
    # change to absolute
    path = File.join(File.absolute_path(File.dirname(__FILE__)), path)
    name = File.basename(path, File.extname(path))
    define_method "test_#{name}" do
      rake.add_import path
      rake.load_rakefile
      # a factory to wrap given block and use later
      ctx = TestContext.new
      rake['default'].invoke(ctx)
      ctx.tests.each { |t| instance_eval(&t) }
      # actual_file = `rake -f #{path}`.chomp
      # assert_equal File.read(actual_file), File.read(actual_file + '.expected')

      rake.clear
    end
  end

  def setup
    FileUtils.rm_rf('_out')
  end
end
