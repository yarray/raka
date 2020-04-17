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

  def initialize(compiler, context, chain, inline_scope_pattern)
    @compiler = compiler
    @context = context
    @chain = chain
    @inline_scope_pattern = inline_scope_pattern
  end

  def _captures_(target)
    matched = _pattern_.match(target)
    keys = matched.names.map(&:to_sym)
    Hash[keys.zip(matched.captures)]
  end

  def _parse_output_(output)
    # xxx? is for minimal match
    out_pattern = %r{^((?<scope>\S+)/)?}.source
    if !@inline_scope_pattern.nil?
      out_pattern += %r{(?<output_scope>(#{@inline_scope_pattern})/)}.source
    end
    out_pattern += %r{(?<stem>(\S+))(?<ext>\.[^\.]+)$}.source
    info = Regexp.new(out_pattern).match(output)
    res = Hash[info.names.zip(info.captures)]
    if !info[:scope].nil?
      info[:scope].chomp! '/'
      scopes = Regexp.new(_scope_pattern_).match(info[:scope]).captures
      scopes[1..].each_with_index do |scope, i|
        res["scope#{scopes.length - 1 - i - 1}"] = scope
      end
    end

    name_details = /^(\S+?)__(\S+)$/.match(info[:stem])
    res = if name_details
            res.merge(func: name_details[1], input_stem: name_details[2])
          else
            res.merge(func: nil, input_stem: nil)
          end
    res = res.merge(captures: OpenStruct.new(_captures_(output)))
    OpenStruct.new res
  end

  # attach a new item to the chain
  def _attach_(item)
    Token.new(@compiler, @context, @chain + [item], @inline_scope_pattern)
  end

  def method_missing(sym, *args)
    # puts sym
    # if ends with '=' then is to compile;
    # if not but has a arg then it is template token, push template;
    # else is inconclusive so just push symbol
    if sym.to_s.end_with? '='
      @compiler.compile(_attach_(sym.to_s.chomp('=')), args.first)
    elsif !args.empty?
      _attach_ args.first.to_s
    else
      _attach_ sym.to_s
    end
  end

  # non capture matching anything
  def _(*args)
    if !args.empty?
      _attach_ args.first.to_s
    else
      _attach_ '\S+'
    end
  end

  def _=(rhs)
    @compiler.compile(_attach_('\S+'), rhs)
  end

  def _input_?
    @chain.length > 1
  end

  # TODO: no @var used, bad smell
  def _inputs_(output, ext)
    # no input
    return [] if @chain.length == 1

    # match the body part besides the scope (if not scoped), leading xxx__ and .ext of output
    info = _parse_output_(output)
    input_stem = /^\S+?__(\S+)$/.match(info.stem)[1]
    [info.scope ? "#{info.scope}/#{input_stem}.#{ext}" : "#{input_stem}.#{ext}"]
  end

  def _scope_pattern_
    '((?:(\S+)/)?' +
      (@context.scopes.map {|layer| "(#{layer.join('|')})" }).join('/') +
      ')'
  end

  def _pattern_
    # scopes as leading
    leading = @context.scopes.length > 0 ? _scope_pattern_ + '/' : _scope_pattern_
    if !@inline_scope_pattern.nil?
      leading += "(#{@inline_scope_pattern})/"
    end
    body = @chain.reverse.map { |s| "(#{s})" }.join('__')
    Regexp.new('^' + leading + body + '\.' + @context.ext.to_s + '$')
  end

  def _template_(scope=nil)
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
