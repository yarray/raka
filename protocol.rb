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

    puts code
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
  def initialize(src, libs = [])
    @src = src
    @libs = libs
  end

  def build(code)
    libraries = ([
      :pipeR,
    ] + @libs).map { |name| "suppressPackageStartupMessages(library(#{name}))" }

    sources = ([
      :io,
    ] + (@src ? [@src] : [])).map { |name| "source('#{SRC_DIR}/#{name}.R')" }

    extra = [
      '`|` <- `%>>%`',
      "conn_args <- list(host='#{HOST}', user='#{USER}', dbname='#{DB}', port='#{PORT}')",
      "args <- commandArgs(trailingOnly = T)",
      "sql_input    <- init_sql_input(conn_args, args[1])",
      "table_input  <- init_table_input(conn_args, args[1])",
      "table_output <- init_table_output(conn_args, args[1])"
    ]

    [libraries, sources, extra, code].join "\n"
  end

  def run_script(env, fname, task)
    env.send :sh, "Rscript #{fname} '#{task.scope || "public"}'"
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
  # Sometimes we want to use the psql command with bash directly
  def self.sh_cmd(scope)
    env_vars = "PGOPTIONS='-c search_path=#{scope ? scope + ',' : ''}public' "
    "#{env_vars} psql -h #{HOST} -p #{PORT} -U #{USER} -d #{DB} -v ON_ERROR_STOP=1"
  end

  def initialize(options={})
    @options = options
  end

  def build(code)
    if @options[:create].to_s == 'table'
      "DROP TABLE IF EXISTS :_name_;" +
      "CREATE TABLE :_name_ AS (" + code + ");"
    end
  end

  def run_script(env, fname, task)
    params = Hash[(@options[:params] || {}).map { |k, v| [k, resolve.call(v)] }]
    param_str = params.map { |k, v| "-v #{k}=\"#{v}\"" }.join(' ')

    bash env, %{
    #{self.class.sh_cmd(task.scope)} #{param_str} -v _name_=#{task.stem} \
      -f #{fname} | tee #{fname}.log
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

    @runner = Psql.new(@options)
    tmp_f = @runner.create_tmp(@runner.build(File.read(script_file).strip().chomp(';')))
    @runner.run_script env, tmp_f, task
  end
end

creator :shell, Shell
creator :psql, Psql
creator :r, R

def psqlf(*args, &block)
  [PsqlFile.new(*args, &block)]
end
