# Context to preserve during the token chaining
class Context
  attr_reader :ext
  attr_reader :scopes

  def initialize(ext, scopes=[])
    @ext = ext
    @scopes = scopes
  end
end

class Token
  attr_reader :chain

  def self.parse_output(output)
    # xxx? is for minimal match
    info = %r{^((?<scope>\S+)/)*(?<stem>(\S+))(?<ext>\.[^\.]+)$}
      .match(output)
    OpenStruct.new Hash[info.names.zip(info.captures)]
  end

  def initialize(compiler, context, chain)
    @compiler = compiler
    @context = context
    @chain = chain
  end

  # attach a new item to the chain
  def attach(item)
    Token.new(@compiler, @context, @chain + [item])
  end

  def method_missing(sym, *args)
    # if ends with '=' then is to compile;
    # if not but has a arg then it is template token, push template;
    # else is inconclusive so just push symbol
    if sym.to_s.end_with? '='
      @compiler.compile(attach(sym.to_s.chomp('=')), args.first)
    elsif !args.empty?
      attach args.first.to_s
    else
      attach sym.to_s
    end
  end

  def has_inputs?
    @chain.length > 1
  end

  # TODO no @var used, bad smell
  def inputs(output, ext, scoped=true)
    # no input
    return [] if @chain.length == 1

    # match the body part besides the scope (if not scoped), leading xxx__ and .ext of output
    info = Token.parse_output(output)
    input_stem = /^\S+?__(\S+)$/.match(info.stem)[1]
    [scoped && info.scope ?
      "#{info.scope}/#{input_stem}.#{ext}" : "#{input_stem}.#{ext}"]
  end

  def pattern
    # scopes as leading
    leading = @context.scopes.empty? ? '' : "(#{@context.scopes.join '|'})/"
    body = @chain.reverse.map(&:to_s).join('__')
    Regexp.new('^' + leading + body + '\.' + @context.ext.to_s + '$')
  end

  def template
    @chain.reverse.join('__') + '.' + @context.ext.to_s
  end

  # These two methods indicate that this is a pattern token
  def [](pattern)
    symbol = @chain.pop.to_s
    # if the pattern contains child pattern like percent_(\d+), we change the capture to
    # named capture so that it can be captured later. The name is symbol with the index, like func0
    pattern = pattern.gsub(/\(\S+?\)/).with_index { |m, i| "(?<#{symbol}#{i}>#{m})" }

    if symbol == '_' # _ means "not bound"
      @chain.push pattern.to_s
    else
      @chain.push "(?<#{symbol}>(#{pattern}))"
    end
    self
  end

  def []=(pattern, value)
    @compiler.compile(self[pattern], value)
  end
end
