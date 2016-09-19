require 'securerandom'
require 'rake'

class Protocol
  attr_accessor :code

  def attach(env)
    @env = env
  end

  def create_tmp(content)
    tmpfile = "/tmp/#{SecureRandom.uuid}"

    File.open(tmpfile, 'w') do |f|
      f.write content
    end

    tmpfile
  end

  def run
    throw 'No code to run' if @code.nil?

    script_text = build(@code).gsub(/^    |\t/, '')
    run_script create_tmp(script_text)
  end

  # for syntax sugar like shell* <code>
  def *(code)
    @code = code
    [self]
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

def r(*args)
  R.new(*args)
end

def shell(*args)
  Shell.new(*args)
end

def sql(runner)
  Psql.new(*args)
end
