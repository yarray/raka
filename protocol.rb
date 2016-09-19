require 'securerandom'

# There are two methods to provide code to a protocol, either a string literal
# or a ruby block.
class Protocol
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

  # prepare code to make protocol runnable
  def prepare(env, task)
    @env = env
    @code = yield @text if @text
    @code = yield @block.call(task) if @block
    @task = task
  end

  def run
    throw 'No code to run' if @code.nil?

    script_text = build(@code).gsub(/^    |\t/, '')
    run_script create_tmp(script_text)
  end

  # template methods:
  # build(code)
  def build(code)
    code
  end
  # run_script(fname)
end

class R < Protocol
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

  def run_script(fname)
    @env.send :sh, "Rscript #{fname}"
  end
end

class Shell < Protocol
  def initialize(base_dir = './')
    @base_dir = base_dir
  end

  def build(code)
    ["cd #{@base_dir}", 'set -e', code].join "\n"
  end

  def run_script(fname)
    @env.send :sh, "bash #{fname}"
  end
end

class Psql < Protocol
  def self.common(common_options)
    @@common_options = common_options
  end

  # options Array like ['-U user', '-p 5432']
  def initialize(options)
    @options = options.update @@common_options
  end

  def run_script(fname)
    env_vars = @task.scope ? "PGOPTIONS='-c search_path=#{@task.scope},public' " : ''
    @env.send :sh, env_vars + "psql #{@options} -f #{fname}"
    @env.send :sh, "touch #{@task.name}"
  end
end

def creator(name, klass)
  define_method name do |*args, &block|
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

# A special "Protocol" for ease of SQL file invoking
class PsqlFile
  def initialize(options, script_file, &block)
    @options = options
    @block = block
    @script_file = script_file
  end

  def prepare(env, task)
    @args = block.call @task

    @runner = Psql.new(options + @args.map { |k, v| "-v #{k}='#{v}'" })
    @runner.prepare env, task
  end

  def run
    @runner.run_script @script_file
  end
end
