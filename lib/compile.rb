# frozen_string_literal: true

require 'fileutils'

require_relative './token'

def array_to_hash(array)
  array.nil? ? {} : Hash[((0...array.size).map { |i| i.to_s.to_sym }).zip array]
end

def protect_percent_symbol(text)
  anchor = '-_-_-'
  safe_text = text.gsub(/%(?=[^\s{]+)/, anchor) # replace % not in shape of %{ to special sign
  safe_text = yield safe_text
  safe_text.gsub(anchor, '%') # replace % not in shape of %{ to special sign
end

# compiles rule (lhs = rhs) to rake task
class DSLCompiler
  attr_reader :env

  # keep env as running environment of rake since we want to inject rules
  def initialize(env, options)
    @env = env
    @options = options
  end

  # Raka task structure, input task is rake's task pushed into blocks
  def dsl_task(token, task)
    name = task.name
    deps = task.prerequisites

    output_info = token._parse_output_ name
    task_info = {
      name: name,
      deps: deps,
      deps_str: deps.join(','),
      input: deps.first || '',
      task: task
    }
    OpenStruct.new(output_info.to_h.merge(task_info))
  end

  # resolve auto variables with only output info,
  # useful when resolve extra deps (task is not available yet)
  def resolve_by_output(target, output_info)
    info = output_info
    text = target.respond_to?(:_template_) ? target._template_(info.scope).to_s : target.to_s
    text = text
      .gsub('$(scope)', info.scope.nil? ? '' : info.scope)
      .gsub('$(output_scope)', info.output_scope.nil? ? '' : info.output_scope)
      .gsub('$(stem)', info.stem)
      .gsub('$(input_stem)', info.input_stem.nil? ? '' : info.input_stem)
      .gsub('$@', info.name)

    protect_percent_symbol text do |safe_text|
      safe_text = safe_text % (info.to_h.merge info.captures.to_h)
      safe_text = safe_text.gsub(/\$\(scope(\d+)\)/, '%{\1}') % array_to_hash(info.scopes)
      safe_text.gsub(/\$\(output_scope(\d+)\)/, '%{\1}') % array_to_hash(info.output_scope_captures)
    end
  end

  # resolve auto variables with dsl task
  def resolve(target, task)
    # convert target to text whether it is expression or already text
    text = resolve_by_output target, task

    # convert $0, $1 to the universal shape of %{dep} as captures
    text = text
      .gsub('$^', task.deps_str)
      .gsub('$<', task.input || '')

    protect_percent_symbol text do |safe_text|
      # add numbered auto variables like $0, $2 referring to the first and third deps
      safe_text.gsub(/\$\(dep(\d+)\)/, '%{\1}') % array_to_hash(task.deps)
    end
  end

  def rule_action(lhs, actions, extra_tasks, task)
    return if actions.empty?

    task = dsl_task(lhs, task)
    @env.logger.info "raking #{task.target}"
    unless task.scope.nil?
      folder = task.scope
      folder = File.join(task.scope, task.output_scope) unless task.output_scope.nil?
      FileUtils.makedirs(folder)
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

  # build one rule
  def create_rule(lhs, input_ext, actions, extra_deps, extra_tasks)
    # the "rule" method is private, maybe here are better choices
    @env.send(:rule, lhs._pattern_ => [proc do |target|
      inputs = lhs._inputs_(target, input_ext)
      output = lhs._parse_output_(target)
      plain_extra_deps = extra_deps.map do |templ|
        resolve_by_output(templ, output)
      end
      # main data source and extra dependencies
      inputs + plain_extra_deps
    end]) do |task|
      # rake continue task even if dependencies not met, we handle ourselves
      absence = task.prerequisites.find_index { |f| !File.exist? f }
      unless absence.nil?
        @env.logger.warn\
          "Dependent #{task.prerequisites[absence]} does not exist, skip task #{task.name}"
        next
      end
      rule_action(lhs, actions, extra_tasks, task)
    end
  end

  # compile token = rhs to rake rule
  # rubocop:disable Style/MethodLength
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

    unless lhs._input_?
      create_rule lhs, proc { [] }, actions, extra_deps, extra_tasks
      return
    end

    # We generate a rule for each possible input type
    @options.input_types.each do |ext|
      # We find auto source from both THE scope and the root
      create_rule lhs, ext, actions, extra_deps, extra_tasks
    end
  end
end
# rubocop:enable Style/MethodLength
