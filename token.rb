# Context to preserve during the token chaining
class Context
	attr_reader :ext
	attr_reader :scopes

	def initialize(ext, scopes = [])
		@ext = ext
		@scopes = scopes
	end
end

class Token
  attr_reader :chain

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

  def input(output, ext)
    # no input
    return '' if @chain.length == 1

    # match the body part besides the leading xxx__ and .ext, ? is for minimal match
    pattern.match(output).to_s.gsub(/^\S+?__/, '').gsub(/\.\S+$/, '') +
      '.' + ext.to_s
  end

  def pattern
    body = @chain.reverse.map(&:to_s).join('__')
    Regexp.new('^' + body + '\.' + @context.ext.to_s + '$')
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
