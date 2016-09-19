require 'securerandom'

# There are two methods to provide code to a protocol, either a string literal
# or a ruby block.
class Protocol
  def attach(env)
    @env = env
  end

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
  def prepare(task)
    @code = yield @text if @text
    @code = yield @block.call(task) if @block
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
  def build(code)
    ['set -e', code].join "\n"
  end

  def run_script(fname)
    @env.send :sh, "bash #{fname}"
  end
end

class Psql < Protocol
  def initialize(options)
    @options = options
  end

  def run_script(fname)
    @env.send :sh, "psql #{@options} -f #{fname}"
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
