require './compile'
require './protocol.rb'

# These are where the dsl starts
def file_types(*args)
  args.each do |ext|
    define_method ext do
      Token.new self, [], ext
    end
  end
end

class Token
  attr_reader :chain

  # keep env as running environment of rake since we want to inject rules
  def initialize(env, chain, ext)
    @env = env
    @chain = chain
    @ext = ext
  end

  def method_missing(sym, *args, &block)
    # if ends with '=' then is to compile;
    # if not but has a arg then it is template token, push template;
    # else is inconclusive so just push symbol
    if sym.to_s.end_with? '='
      compile(@env, Token.new(@env, @chain + [sym.to_s.chomp('=')], @ext), args.first)
    elsif !args.empty?
      Token.new @env, @chain + [args.first.to_s], @ext
    else
      Token.new @env, @chain + [sym.to_s], @ext
    end
  end

  def data_pattern
    body = @chain[0, @chain.length - 1].reverse.map(&:to_s).join('__')
    Regexp.new(body.empty? ? '' : (body + '\.' + @ext.to_s + '$'))
  end

  def pattern
    body = @chain.reverse.map(&:to_s).join('__')
    Regexp.new('^' + body + '\.' + @ext.to_s + '$')
  end

  def template
    @chain.reverse.join('__') + '.' + @ext.to_s
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
    compile(self[pattern], value)
  end
end