# hello_test.rb
require "test/unit"

class RakaTest < Test::Unit::TestCase
  all_samples = Dir.glob("**/*/*.raka")
  all_samples = ['scope/long.raka']
  all_samples.each do |path|
    name = File.basename(path, File.extname(path))
    define_method "test_#{name}" do
      actual_file = `rake -f #{path}`.chomp
      assert_equal File.read(actual_file), File.read(actual_file + '.expected')
    end
  end
end
