require 'securerandom'

def remove_common_indent(s)
  s.gsub(/^#{s.scan(/^[ \t]+(?=\S)/).min}/, '')
end

def bash(env, cmd)
  puts remove_common_indent(cmd)
  env.send :sh, "bash " + create_tmp(remove_common_indent(
    %{set -e
      set -o pipefail

      #{cmd}
    }))
end

# protocol conforms the interface:
#
# run(env, task) resolve
#
# run :: rake's main -> dsl task(see compiler) -> void
# resolve :: str -> str

# There are two methods to provide code to a language protocol, either a string literal
# OR a ruby block. Cannot choose both.
class LanguageProtocol
  def set_block(block)
    @block = block
  end

  def create_tmp(content)
    tmpfile = "/tmp/#{SecureRandom.uuid}"

    File.open(tmpfile, 'w') do |f|
      f.write content
    end

    tmpfile
  end

  # for syntax sugar like shell* <code text>
  def *(text)
    @text = text
    [self]
  end

  # a block::str -> str should be given to resolve the bindings in code text
  def run(env, task)
    code = yield @text if @text
    code = yield @block.call(task) if @block

    throw 'No code to run' if code.nil?

    script_text = build(remove_common_indent(code))
    run_script env, create_tmp(script_text), task
  end

  # template methods:
  # build(code)
  def build(code)
    code
  end
  # run_script(fname, task)
end

class R < LanguageProtocol
  def initialize(libs)
    @libs = libs
  end

  def build(code)
    libraries = [
      :pipeR,
    ].map { |name| "suppressPackageStartupMessages(library(#{name}))" }

    sources = ([
      :io,
    ] + libs).map { |name| "source('src/#{name}.R')" }

    extra = [
      '`|` <- `%>>%`',
    ]

    [libraries, sources, extra, code].join "\n"
  end

  def run_script(env, fname, task)
    env.send :sh, "Rscript #{fname}"
  end
end

class Shell < LanguageProtocol
  def initialize(base_dir = './')
    @base_dir = base_dir
  end

  def build(code)
    ["cd #{@base_dir}", 'set -e', code].join "\n"
  end

  def run_script(env, fname, task)
    env.send :sh, "bash #{fname}"
  end
end

# requires HOST, PORT, USER, DB
class Psql < LanguageProtocol
  def initialize(opt_str='')
    @opt_str = opt_str
  end

  def run_script(env, fname, task)
    env_vars = task.scope ? "PGOPTIONS='-c search_path=#{task.scope},public' " : ''

    bash env, %{
    #{env_vars} psql -h #{HOST} -p #{PORT} -U #{USER} -d #{DB} \\
      -v ON_ERROR_STOP=1 #{@opt_str} -f #{fname} | tee #{fname}.log
    mv #{fname}.log #{task.name}
    }
  end
end

def creator(name, klass)
  define_singleton_method name do |*args, &block|
    res = klass.new(*args)
    if block
      res.set_block(block)
      [res]
    else
      res # if no block, waiting for * to add code text
    end
  end
end

# requires SRC_DIR and all Psql requirements
class PsqlFile
  def initialize(options={})
    @options = options
  end

  def run(env, task, &resolve)
    if @options.has_key? :script_file
      script_file = resolve.call @options[:script_file]
    elsif @options.has_key? :script_name
      script_file = "#{SRC_DIR}/#{resolve.call @options[:script_name]}"
    else
      # infer from the task name
      script_file = "#{SRC_DIR}/#{task.stem}.sql"
    end

    params = Hash[(@options[:params] || {}).map { |k, v| [k, resolve.call(v)] }]

    @runner = Psql.new(params.map { |k, v| "-v #{k}='#{v}'" }.join ' ')
    @runner.run_script env, script_file, task
  end
end

creator :shell, Shell
creator :psql, Psql
creator :r, R

def psqlf(*args, &block)
  [PsqlFile.new(*args, &block)]
end
