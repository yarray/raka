# frozen_string_literal: true

require 'fileutils'

require_relative './token'

# compiles rule (lhs = rhs) to rake task
class DSLCompiler
  # keep env as running environment of rake since we want to inject rules
  def initialize(env, options)
    @env = env
    @options = options
  end

  # task is rake's task pushed into blocks
  # offer two shapes: name only and full task to unify argument resolving
  def dsl_task(token, task)
    # if rake task
    if task.respond_to? :name
      name = task.name
      deps = task.prerequisites
    # if target
    else
      name = task
      deps = []
    end
    output_info = token.parse_output name
    OpenStruct.new(
      output_info.to_h.merge({
        name: name,
        deps: deps,
        deps_str: deps.join(','),
        dep: deps.first || '',
        task: task
      })
    )
  end

  def resolve(target, task)
    # convert target to text whether it is expression or already text
    text = target.respond_to?(:template) ? target.template(task.scope).to_s : target.to_s

    # add numbered auto variables like $0, $2 referring to the first and third deps
    args = Hash[(0...task.deps.size).zip task.deps].merge task.captures.to_h

    # gsub refer ith dependency as $i
    text
      .gsub('$(scope)', task.scope || '')
      .gsub('$(stem)', task.stem)
      .gsub('$(input_stem)', task.input_stem || '')
      .gsub('$@', task.name)
      .gsub('$^', task.deps_str)
      .gsub('$<', task.dep || '')
      .gsub(/\$(\d+)/, '%{\1}') % args
  end


  # build one rule
  def create_rule(lhs, get_inputs, actions, extra_deps, extra_tasks)
    # the "rule" method is private, maybe here are better choices
    @env.send(:rule, lhs.pattern => [proc do |target|
      inputs = get_inputs.call target
      extra_deps = extra_deps.map do |templ|
        resolve(templ, lhs.parse_output(target).captures)
      end
      # main data source and extra dependencies
      inputs + extra_deps
    end]) do |task|
      next if actions.empty?

      task = dsl_task(lhs, task)
      if !task.scope.empty?
        FileUtils.makedirs(task.scope)
      end
      actions.each do |action|
        action.call @env, task do |code|
          resolve(code, task)
        end
      end

      extra_tasks.each do |templ|
        Rake::Task[resolve(templ, task)].invoke
      end
    end
  end

  # compile token = rhs to rake rule
  def compile(lhs, rhs)
    unless @env.instance_of?(Object)
      raise "DSL compile error: seems not a valid @env of rake with class #{@env.class}"
    end

    # the format is [dep, ...] | [action, ...] | [post, ...], where the posts
    # are those will be raked after the actions
    actions_start = rhs.find_index { |item| item.respond_to?(:call) }

    # case 1: has action
    if actions_start
      extra_deps = rhs[0, actions_start]
      actions_end = rhs[actions_start, rhs.length].find_index do |item|
        !item.respond_to?(:call)
      end

      # case 1.1: has post
      if actions_end
        actions_end += actions_start
        actions = rhs[actions_start, actions_end]
        extra_tasks = rhs[actions_end, rhs.length]
      # case 1.2: no post
      else
        actions = rhs[actions_start, rhs.length]
        extra_tasks = []
      end
    # case 2: no action
    else
      extra_deps = rhs
      actions = []
      extra_tasks = []
    end

    unless lhs.inputs?
      create_rule lhs, proc { [] }, actions, extra_deps, extra_tasks
      return
    end

    # We generate a rule for each possible input type
    @options.input_types.each do |ext|
      get_inputs = proc { |output| lhs.inputs(output, ext) }

      # We find auto source from both THE scope and the root
      create_rule lhs, get_inputs, actions, extra_deps, extra_tasks
    end
  end
end
