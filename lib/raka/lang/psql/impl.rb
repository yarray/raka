# frozen_string_literal: true

require_relative '../../protocol'

def bash(env, cmd)
  code = remove_common_indent(
    %(set -e
      set -o pipefail

      #{cmd}
    )
  )
  # puts code
  env.send :sh, 'bash ' + create_tmp(code)
end

# postgresql protocol using psql, requires HOST, PORT, USER, DB
class Psql
  # Sometimes we want to use the psql command with bash directly
  def sh_cmd(schema)
    c = @conn
    env_vars = "PGOPTIONS='-c search_path=#{schema.empty? ? '' : schema + ','}public' "
    "PGPASSWORD=#{c.password} #{env_vars} psql -h #{c.host} -p #{c.port} -U #{c.user} -d #{c.db} -v ON_ERROR_STOP=1"
  end

  # 1. do not add required argument here, so psql.config will work or we can only use psql(conn: xxx).config
  def initialize(conn: nil, create: 'mview', schema: '', params: {})
    @create = create
    @params = params
    @schema = schema
    @conn = conn
  end

  def build(code, _)
    # 2. lazily check the argument only when used
    raise 'argument conn required' if @conn.nil?

    if @create.to_s == 'table'
      'DROP TABLE IF EXISTS :_schema_:_name_;' \
        'CREATE TABLE :schema:_name_ AS (' + code + ');'
    elsif @create.to_s == 'mview'
      'DROP MATERIALIZED VIEW IF EXISTS :_schema_:_name_;' \
        'CREATE MATERIALIZED VIEW :schema:_name_ AS (' + code + ');'
    else
      code
    end
  end

  def run_script(env, fname, task)
    param_str = (@params || {}).map { |k, v| "-v #{k}=\"#{v}\"" }.join(' ')
    schema = @schema.empty? ? task.rule_scopes.join('__') : @schema

    bash env, %(
    #{sh_cmd(schema)} #{param_str} -v _name_=#{task.output_stem} \
      -v _schema_=#{schema.empty? ? '' : schema + '.'} -f #{fname} | tee #{fname}.log
    mv #{fname}.log #{task.name}
    )
  end
end

creator :psql, Psql
