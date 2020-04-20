# frozen_string_literal: true

# Context to preserve during the token chaining
class Context
  attr_reader :ext
  attr_reader :scopes

  def initialize(ext, scopes = [])
    @ext = ext
    @scopes = scopes
  end
end

# methods like _xx_ are preserved for token
def internal(name)
  name.length > 1 && name.to_s.start_with?('_') && name.to_s.end_with?('_')
end

# A raka expression is a list of linked tokens. The Token
# class store current token, info of previous tokens, and context.
# It plays rule of both token and expr
class Token
  attr_reader :chain

  def initialize(compiler, context, chain, inline_scope)
    @compiler = compiler
    @context = context
    @chain = chain
    @inline_scope = inline_scope
  end

  def _captures_(target)
    matched = _pattern_.match(target)
    keys = matched.names.map(&:to_sym)
    Hash[keys.zip(matched.captures)]
  end

  # rubocop:disable Style/MethodLength # long but straightforward
  def _parse_output_(output)
    # xxx? is for minimal match
    out_pattern = %r{^((?<scope>\S+)/)?}.source
    out_pattern += %r{(?<output_scope>#{@inline_scope})/}.source unless @inline_scope.nil?
    out_pattern += /(?<stem>(\S+))(?<ext>\.[^\.]+)$/.source
    info = Regexp.new(out_pattern).match(output)
    res = Hash[info.names.zip(info.captures)]
    unless info[:scope].nil?
      scopes = Regexp.new(_scope_pattern_).match(info[:scope]).captures
      res[:scopes] = scopes[1..-1].reverse
    end
    if !@inline_scope.nil? && !info[:output_scope].nil?
      segs = Regexp.new(@inline_scope).match(info[:output_scope]).captures
      res[:output_scopes] = segs
    end

    name_details = /^(\S+?)__(\S+)$/.match(info[:stem])
    res = if name_details
            res.merge(func: name_details[1], input_stem: name_details[2])
          else
            res.merge(func: nil, input_stem: nil)
          end
    res = res.merge(captures: OpenStruct.new(_captures_(output)))
    res[:name] = output
    OpenStruct.new res
  end
  # rubocop:enable Style/MethodLength

  # attach a new item to the chain
  def _attach_(item)
    Token.new(@compiler, @context, @chain + [item], @inline_scope)
  end

  def method_missing(sym, *args)
    # if ends with '=' then is to compile;
    # if not but has a arg then it is template token, push template;
    # else is inconclusive so just push symbol
    if sym.to_s.end_with? '='
      @compiler.compile(_attach_(sym.to_s.chomp('=')), args.first)
    elsif !args.empty?
      _attach_ args.first.to_s
    elsif !internal(sym)
      _attach_ sym.to_s
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    internal(name) ? super : true
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

  def _inputs_(output, ext)
    # no input
    return [] if @chain.length == 1

    # match the body part besides the scope (if not scoped), leading xxx__ and .ext of output
    info = _parse_output_(output)
    input_stem = /^\S+?__(\S+)$/.match(info.stem)[1]
    [info.scope ? "#{info.scope}/#{input_stem}.#{ext}" : "#{input_stem}.#{ext}"]
  end

  def _scope_pattern_
    '((?:(\S+)/)?' + (@context.scopes.map { |layer| "(#{layer.join('|')})" }).join('/') + ')'
  end

  def _pattern_
    # scopes as leading
    leading = !@context.scopes.empty? ? _scope_pattern_ + '/' : _scope_pattern_
    leading += "(#{@inline_scope})/" unless @inline_scope.nil?
    body = @chain.reverse.map { |s| "(#{s})" }.join('__')
    Regexp.new('^' + leading + body + '\.' + @context.ext.to_s + '$')
  end

  def _template_(scope = nil)
    (scope.nil? ? '' : scope + '/') + (@inline_scope.nil? ? '' : @inline_scope + '/') +
      @chain.reverse.join('__') + '.' +
      @context.ext.to_s
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
