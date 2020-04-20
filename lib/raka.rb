# frozen_string_literal: true

require 'logger'

require_relative './compile'
require_relative './protocol'
require_relative './token'

# initialize raka
class Raka
  def create_logger
    @env.define_singleton_method :logger do
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger
    end
  end

  def define_token_creator(ext)
    # closures
    env = @env
    options = @options
    scopes = @scopes
    @env.define_singleton_method ext do |*args|
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
    create_logger

    defaults = {
      output_types: [:csv], input_types: [],
      scopes: [],
      protocols: ['lang/shell'],
      user_protocols: []
    }

    @options = options = OpenStruct.new(defaults.merge(options))
    @options.input_types |= @options.output_types # any output can be used as intermediate
    # specify root of scopes in options, scopes will append to each root
    @scopes = options.scopes.empty? ? [] : [options.scopes]
    @options.protocols.each { |path| require_relative "#{path}/protocol" }
    @options.user_protocols.each { |path| require path.to_s }

    # These are where the dsl starts
    @options.output_types.each do |ext|
      define_token_creator ext
    end
  end

  def scope(*names, &block)
    @scopes.push(names)
    block.call
    @scopes.pop
  end
end
