# frozen_string_literal: true

require_relative '../../protocol'

def bash(env, cmd)
  code = remove_common_indent(
    %(set -e
      set -o pipefail

      #{cmd}
    )
  )
  env.send :sh, 'bash ' + create_tmp(code)
end

# DuckDB protocol with two modes:
# 1. Persistent mode: operations on .db file with CREATE TABLE
# 2. Ad-hoc mode: parquet in/out using COPY operations
class Duckdb
  def initialize(database: nil, params: {})
    @params = params
    @database = database
    @mode = @database ? :persistent : :adhoc
  end

  def duckdb_cmd
    case @mode
    when :persistent
      "duckdb #{@database}"
    when :adhoc
      'duckdb'
    end
  end

  def build(code, _task)
    # Replace parameter placeholders
    processed_code = code
    (@params || {}).each do |key, value|
      processed_code = processed_code.gsub("$#{key}", "'#{value}'")
    end

    case @mode
    when :persistent
      "DROP TABLE IF EXISTS :_name_; CREATE TABLE :_name_ AS (#{processed_code});"
    when :adhoc
      "COPY (#{processed_code}) TO ':output:' (FORMAT PARQUET);"
    end
  end

  def run_script(env, fname, task)
    case @mode
    when :persistent
      bash env, %(
      #{duckdb_cmd} -c "$(cat #{fname} | sed 's|:_name_|#{task.output_stem}|g')" | tee #{fname}.log
      echo "#{@database}" > #{task.name}
      )
    when :adhoc
      bash env, %(
      cat #{fname} | sed 's|:output:|#{task.name}|g' | #{duckdb_cmd} | tee #{fname}.log
      )
    end
  end
end

creator :duckdb, Duckdb
