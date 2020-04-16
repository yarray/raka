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

  def captures(target)
    matched = pattern.match(target)
    keys = matched.names.map(&:to_sym)
    Hash[keys.zip(matched.captures)]
  end

  def parse_output(output)
    # xxx? is for minimal match
    info = %r{^((?<scope>\S+)/)*(?<stem>(\S+))(?<ext>\.[^\.]+)$}.match(output)
    res = Hash[info.names.zip(info.captures)]
    if !info[:scope].nil?
      info[:scope].chomp! '/'
    end
    name_details = /^(\S+?)__(\S+)$/.match(info[:stem])
    res = if name_details
            res.merge(func: name_details[1], input_stem: name_details[2])
          else
            res.merge(func: nil, input_stem: nil)
          end
    res = res.merge(captures: OpenStruct.new(captures(output)))
    OpenStruct.new res
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

  # non capture matching anything
  def _(*args)
    if !args.empty?
      attach args.first.to_s
    else
      attach '\S+'
    end
  end

  def _=(rhs)
    @compiler.compile(attach('\S+'), rhs)
  end

  def inputs?
    @chain.length > 1
  end

  # TODO: no @var used, bad smell
  def inputs(output, ext)
    # no input
    return [] if @chain.length == 1

    # match the body part besides the scope (if not scoped), leading xxx__ and .ext of output
    info = parse_output(output)
    input_stem = /^\S+?__(\S+)$/.match(info.stem)[1]
    puts [info.scope ? "#{info.scope}/#{input_stem}.#{ext}" : "#{input_stem}.#{ext}"]
    [info.scope ? "#{info.scope}/#{input_stem}.#{ext}" : "#{input_stem}.#{ext}"]
  end

  def scope_pattern
    '(((?:\S+/)?)' +
      (@context.scopes.map {|layer| "(#{layer.join('|')})/" }).join() +
      ')'
  end

  def pattern
    # scopes as leading
    leading = scope_pattern
    body = @chain.reverse.map { |s| "(#{s})" }.join('__')
    Regexp.new('^' + leading + body + '\.' + @context.ext.to_s + '$')
  end

  def template(scope=nil)
    (scope ? scope + '/' : '') + @chain.reverse.join('__') + '.' + @context.ext.to_s
  end

  # These two methods indicate that this is a pattern token
  def [](pattern = '\S+')
    symbol = @chain.pop.to_s
    # if the pattern contains child pattern like percent_(\d+), we change the capture to
    # named capture so that it can be captured later. The name is symbol with the index, like func0
    pattern = pattern.gsub(/\(\S+?\)/).with_index { |m, i| "(?<#{symbol}#{i}>#{m})" }

    if symbol == '\S+' # match-everything and not bound
      @chain.push pattern.to_s
    else
      @chain.push "(?<#{symbol}>(#{pattern}))"
    end
    self
  end

  def []=(pattern = '\S+', value = '')
    @compiler.compile(self[pattern], value)
  end
end
