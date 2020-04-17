require 'fileutils'
require "test/unit"
require 'rake'

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
  # all_samples = ['core/extra_dep.raka']
  all_samples.each do |path|
    # change to absolute
    name = File.dirname(path).gsub('/', '_') + '_' + File.basename(path, File.extname(path))
    define_method "test_#{name}" do
      rake.add_import path
      rake.load_rakefile
      # a factory to wrap given block and use later
      begin
        ctx = TestContext.new
        rake['default'].invoke(ctx)
        ctx.tests.each { |t| instance_eval(&t) }
      ensure
        rake.clear
      end
    end
  end

  def setup
    FileUtils.rm_rf('_out')
  end
end
