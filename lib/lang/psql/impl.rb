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

creator :psql, Psql
