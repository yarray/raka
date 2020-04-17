require_relative './compile'
require_relative './protocol'
require_relative './token'

# initialize raka
class Raka
  def initialize(env, options)
    @env = env

    defaults = { output_types: [:csv], input_types: [], scopes: nil }
    @options = options = OpenStruct.new(defaults.merge(options))
    options.input_types |= options.output_types  # any output can be used as intermediate
    # specify root of scopes in options, scopes will append to each root
    @scopes = options.scopes.nil? ? [] : [options.scopes]

    scopes = @scopes
    # options.output_types = OutputType.parse_option(options.output_types || [:csv])
    # These are where the dsl starts
    options.output_types.each do |ext|
      env.define_singleton_method ext do |*args|
        # Here the compiler are bound with @options so that when we change @options
        # using methods like scope in Rakefile, the subsequent rules defined will honor
        # the new settings
        # clone to fix the scopes when defining rule
        inline_scope_pattern = args.length > 0 ? args[0] : nil
        Token.new(DSLCompiler.new(env, options), Context.new(ext, scopes.clone), [], inline_scope_pattern)
      end
    end
  end

  def scope(*names, &block)
    @scopes.push(names)
    block.call
    @scopes.pop
  end
end
