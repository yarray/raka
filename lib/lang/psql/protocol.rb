# frozen_string_literal: true

require_relative '../../protocol'

def bash(env, cmd)
  code = remove_common_indent(
    %(set -e
      set -o pipefail

      #{cmd}
    )
  )
  puts code
  env.send :sh, 'bash ' + create_tmp(code)
end

# postgresql protocol using psql, requires HOST, PORT, USER, DB
class Psql
  # Sometimes we want to use the psql command with bash directly
  def self.sh_cmd(scope)
    env_vars = "PGOPTIONS='-c search_path=#{scope ? scope + ',' : ''}public' "
    "#{env_vars} psql -h #{HOST} -p #{PORT} -U #{USER} -d #{DB} -v ON_ERROR_STOP=1"
  end

  def initialize(create:, params:)
    @create = create
    @params = params
  end

  def build(code, _)
    if @create.to_s == 'table'
      'DROP TABLE IF EXISTS :_name_;' \
        'CREATE TABLE :_name_ AS (' + code + ');'
    else
      code
    end
  end

  def run_script(env, fname, task)
    param_str = (@params || {}).map { |k, v| "-v #{k}=\"#{v}\"" }.join(' ')

    bash env, %(
    #{self.class.sh_cmd(task.scope)} #{param_str} -v _name_=#{task.stem} \
      -f #{fname} | tee #{fname}.log
    mv #{fname}.log #{task.name}
    )
  end
end

# A special LanguageProtocol, requires SRC_DIR and all Psql requirements
class PsqlFile
  def initialize(params: {}, script_file:, script_name:, **_kwargs)
    @params = params
    @script_file = script_file
    @script_name = script_name
    @extra_kwargs = kwargs
  end

  def call(env, task, &resolve)
    @params = Hash[(@params || {}).map { |k, v| [k, resolve.call(v)] }]
    script_file = if !@script_file.nil?
                    resolve.call @script_file
                  elsif !@script_name.nil?
                    "#{SRC_DIR}/#{resolve.call @script_name}"
                  else
                    # infer from the task name
                    "#{SRC_DIR}/#{task.stem}.sql"
                  end

    runner = Psql.new(params: params, **@extra_kwargs)
    tmp_f = runner.create_tmp(runner.build(File.read(script_file).strip.chomp(';')))
    runner.run_script env, tmp_f, task
  end
end

creator :psql, Psql

def psqlf(*args, **kwargs, &block)
  [PsqlFile.new(*args, **kwargs, &block)]
end
