require 'securerandom'

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

    script_text = build(code).gsub(/^    |\t/, '')
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

class Psql < LanguageProtocol
  def initialize(opt_str)
      @opt_str = opt_str
  end

  def run_script(env, fname, task)
    env_vars = task.scope ? "PGOPTIONS='-c search_path=#{task.scope},public' " : ''
    env.send :sh, env_vars +
      "psql -h #{env.HOST} -p #{env.PORT} -U #{env.USER} -d #{env.DB}" +
      " #{@opt_str} -f #{fname}"
    env.send :sh, "touch #{task.name}"
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

creator :shell, Shell
creator :sql, Psql
creator :r, R


class PsqlFile
  def initialize(search_path = '', script_file = '', &resolve_args)
    @resolve_args = resolve_args
    @script_file = script_file
  end

  def run(env, task)
    if @script_file.empty?
      scope_part = task.scope ? task.scope.to_s + '/' : ''
      search_path = search_path.empty ? env.SRC_DIR : search_path
      # infer from the task name 
      @script_file = "#{search_path}/#{scope_part}#{task.stem}.sql"
    end
    @args = @resolve_args.call @task

    @runner = Psql.new(@args.map { |k, v| "-v #{k}='#{v}'" })
    @runner.run_script env, @script_file, task
  end
end

def psqlf(*args, &block)
    PsqlFile(*args, &block)
end
