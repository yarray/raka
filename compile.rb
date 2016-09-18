require 'rake'

# task is rake's task pushed into blocks
def fulfill_args(cmd, task, named_captures)
  deps = task.prerequisites

  # gsub refer ith dependency as $i
  cmd
    .sub('$@', task.name)
    .sub('$<', deps.join(','))
    .sub('$^', deps.first || '')
    .gsub(/\$(\d+)/, '%{\1}') % ((0...(deps.size - 1)).zip deps) % named_captures
end

# compile token = rhs to rake rule
def compile(env, lhs, rhs)
  action = rhs.pop
  deps = rhs.map(&:template)

  captures = proc do |target|
    matched = lhs.pattern.match(target)
    keys = matched.names.map(&:to_sym)
    Hash[keys.zip(matched.captures)]
  end

  # the "rule" method is private, maybe here are better choices:
  # why "match" in the previous version work?
  env.send(:rule, lhs.pattern => [proc do |target|
    captures_hash = captures.call(target)
    source = lhs.data_pattern.match(target)
    extra = deps.map do |templ|
      templ.to_s % captures_hash
    end
    # main data source and extra dependencies
    (source.to_s.empty? ? [] : [source.to_s]) + extra
  end]) do |task|
    action.attach env
    action.code = fulfill_args action.code, task, captures.call(task.name)
    action.run
  end
end
