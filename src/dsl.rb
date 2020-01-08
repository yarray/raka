require_relative './compile'
require_relative './protocol'
require_relative './token'

# initialize raka
class DSL
  def initialize(env, options)
    @env = env

    defaults = { output_types: [:csv], input_types: [:csv], scopes: [] }
    @options = options = OpenStruct.new(defaults.merge(options))

    # options.output_types = OutputType.parse_option(options.output_types || [:csv])
    # These are where the dsl starts
    options.output_types.each do |ext|
      env.define_singleton_method ext do
        # Here the compiler are bound with @options so that when we change @options
        # using methods like scope in Rakefile, the subsequent rules defined will honor
        # the new settings
        Token.new DSLCompiler.new(env, options), Context.new(ext, options.scopes), []
      end
    end
  end

  def scopes(*args)
    @options.scopes = args
  end
end
