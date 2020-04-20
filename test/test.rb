# frozen_string_literal: true

require 'fileutils'
require 'test/unit'
require 'rake'

require 'optparse'

$options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: example.rb [options]'

  opts.on('-l', '--lang LANG', 'Include language protocols') do |langs|
    $options[:lang] = langs.split ','
  end
end.parse!

# TestContext which provides ability of adding test code in raka files
class TestContext
  def initialize
    @tests = []
  end

  def add_test(&block)
    @tests.push block
  end

  attr_reader :tests
end

# The test wrapper for raka
# RakaTest will look for every .raka files, invoke the default task
# and check the hooked test code. Tested .raka files should define a default
# task like:
#
# ```rake
# task :default, [:ctx] => [<real target>] do |t, args|
#     args.ctx.add_test do
#       # testing code, assert_xx methods are available
#     end
# end
# ```
#
# As shown above, a ctx is passed in and offered an add_test method. Testing code with
# will be wrapped in a test_xx functions so that assert_xx methods are available
class RakaTest < Test::Unit::TestCase
  rake = Rake.application
  rake.init
  # exclude protocol langs, add them on demand
  all_samples = FileList['**/*.raka'].exclude('protocol/*/*.raka')
  all_samples += ($options[:lang].map { |lang| FileList["protocol/#{lang}/*.raka"] }).flatten
  # all_samples = ['protocol/shell/block.raka']
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
