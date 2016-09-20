require_relative './token'

class DSLCompiler
  # keep env as running environment of rake since we want to inject rules
  def initialize(env, options)
    @env = env
    @options = options
  end

  # task is rake's task pushed into blocks
  def dsl_task(task)
    output_info = Token.parse_output task.name
    deps = task.prerequisites
    OpenStruct.new(
      scope: output_info.scope || '',
      stem: output_info.stem,
      name: task.name,
      deps: deps,
      deps_str: deps.join(','),
      dep: deps.first || ''
    )
  end

  def fulfill_args(cmd, task, named_captures)
    args = Hash[(0...task.deps.size).zip task.deps].merge named_captures

    # gsub refer ith dependency as $i
    cmd = cmd
          .sub('$(scope)', task.scope || '')
          .sub('$(stem)', task.stem)
          .sub('$@', task.name)
          .sub('$<', task.deps_str)
          .sub('$^', task.dep)
          .gsub(/\$(\d+)/, '%{\1}') % args
    cmd % named_captures
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
      next if !action
      # prepare text or block depending on the condition of action
      action.prepare @env, dsl_task(task) do |code|
         fulfill_args code, dsl_task(task), captures(pattern, task.name)
      end
      action.run
    end
  end

  def resolve_dep(dep, args)
    if dep.respond_to? :template
      dep.template.to_s % args
    else
      dep
    end
  end

  # compile token = rhs to rake rule
  def compile(lhs, rhs)
    unless @env.instance_of?(Object)
      raise "DSL compile error: seems not a valid @env of rake with class #{@env.class}"
    end

    action = rhs.last.respond_to?(:run) ? rhs.pop : nil

    # We generate a rule for each possible input type
    @options.input_types.each do |ext|
      get_input = proc { |output| lhs.input(output, ext) }
      get_input_unscoped = proc { |output| lhs.input(output, ext, false) }
      get_extra_deps = proc do |captures_hash|
        rhs.map { |dep| resolve_dep(dep, captures_hash) }
      end

      # We find auto source from both THE scope and the root
      create_rule lhs.pattern, get_input, get_extra_deps, action
      create_rule lhs.pattern, get_input_unscoped, get_extra_deps, action
    end
  end
end
