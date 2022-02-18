# frozen_string_literal: true

require 'logger'

require_relative './src/compile'
require_relative './src/protocol'
require_relative './src/token'

# initialize raka
class Raka
  Pattern = Pattern
  P = Pattern
  attr_reader :logger

  def create_logger(level)
    @env.define_singleton_method :logger do
      logger = Logger.new(STDOUT)
      logger.level = level
      logger
    end
  end

  def define_token_creator(ext, ext_alias = nil)
    # closures
    env = @env
    options = @options
    scopes = @scopes
    @env.define_singleton_method(ext_alias || ext) do |*args|
      # Here the compiler are bound with @options so that when we change @options
      # using methods like scope in Rakefile, the subsequent rules defined will honor
      # the new settings
      # clone to fix the scopes when defining rule
      inline_scope_pattern = !args.empty? ? args[0] : nil
      Token.new(
        DSLCompiler.new(env, options), Context.new(ext, scopes.clone),
        [], inline_scope_pattern
      )
    end
  end

  def initialize(env, options)
    @env = env
    defaults = {
      output_types: [:csv], input_types: [],
      type_aliases: {},
      scopes: [],
      lang: ['lang/shell'],
      user_lang: []
    }
    @options = options = OpenStruct.new(defaults.merge(options))

    create_logger options.log_level || (ENV['LOG_LEVEL'] || Logger::INFO).to_i

    @options.input_types |= @options.output_types # any output can be used as intermediate
    # specify root of scopes in options, scopes will append to each root
    @scopes = options.scopes.empty? ? [] : [options.scopes]
    @options.lang.each { |path| load File::join(File::dirname(__FILE__), "#{path}/impl.rb") }
    @options.user_lang.each { |path| load path.to_s + '.rb' }

    # These are where the dsl starts
    @options.output_types.each do |ext|
      define_token_creator(ext, @options.type_aliases[ext])
    end
  end

  def scope(*names, &block)
    @scopes.push(names)
    block.call
    @scopes.pop
  end

  def stem(path)
    File.basename(path, File.extname(path))
  end
end
