require 'rake'

class DSLCompiler
  # keep env as running environment of rake since we want to inject rules
  def initialize(env, options)
    @env = env
    @options = options
  end

  # task is rake's task pushed into blocks
  def fulfill_args(cmd, task, named_captures)
    deps = task.prerequisites

    args = Hash[(0...deps.size).zip deps].merge named_captures
    # gsub refer ith dependency as $i
    cmd = cmd
          .sub('$@', task.name)
          .sub('$<', deps.join(','))
          .sub('$^', deps.first || '')
          .gsub(/\$(\d+)/, '%{\1}') % args
  end

  def captures(pattern, target)
    matched = pattern.match(target)
    keys = matched.names.map(&:to_sym)
    Hash[keys.zip(matched.captures)]
  end

  # build one rule
  def create_rule(pattern, get_input, get_extra_deps, action)
    # the "rule" method is private, maybe here are better choices
    @env.send(:rule, pattern => [proc do |target|
      input = get_input.call target
      extra_deps = get_extra_deps.call captures(pattern, target)
      # main data source and extra dependencies
      (input.to_s.empty? ? [] : [input.to_s]) + extra_deps
    end]) do |task|
      action.attach @env
      action.code = fulfill_args action.code, task, captures(pattern, task.name)
      action.run
    end
  end

  # compile token = rhs to rake rule
  def compile(lhs, rhs)
    unless @env.instance_of?(Object)
      raise "DSL compile error: seems not a valid @env of rake with class #{@env.class}"
    end

    action = rhs.pop
    templates = rhs.map(&:template)

    # We generate a rule for each possible input type
    @options.input_types.each do |ext|
      get_input = proc { |output| lhs.input(output, ext) }
      get_input_unscoped = proc { |output| lhs.input(output, ext, false) }
      get_extra_deps = proc do |captures_hash|
        templates.map { |templ| templ.to_s % captures_hash }
      end

      # We find auto source from both THE scope and the root
      create_rule lhs.pattern, get_input, get_extra_deps, action
      create_rule lhs.pattern, get_input_unscoped, get_extra_deps, action
    end
  end
end
