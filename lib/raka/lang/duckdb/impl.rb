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
  def initialize(database: nil, params: {}, before: nil, after: nil)
    @params = params
    @database = database
    @mode = @database ? :persistent : :adhoc
    @before = before
    @after = after
  end

  def duckdb_cmd
    case @mode
    when :persistent
      "duckdb #{@database}"
    when :adhoc
      'duckdb'
    end
  end

  def process_params(code)
    return code if code.nil?
    
    processed_code = code
    (@params || {}).each do |key, value|
      processed_code = processed_code.gsub("$#{key}", "'#{value}'")
    end
    processed_code
  end

  def build(code, _task)
    # Process parameter placeholders for all parts
    main_sql = process_params(code)
    before_sql = process_params(@before)
    after_sql = process_params(@after)

    # Build SQL parts as separate statements
    sql_parts = []
    
    # Add before hook if present
    sql_parts << before_sql if before_sql
    
    # Add main query based on mode
    case @mode
    when :persistent
      sql_parts << "DROP TABLE IF EXISTS :_name_;"
      sql_parts << "CREATE TABLE :_name_ AS (#{main_sql});"
    when :adhoc
      sql_parts << "COPY (#{main_sql}) TO ':output:' (FORMAT PARQUET);"
    end
    
    # Add after hook if present
    sql_parts << after_sql if after_sql
    
    sql_parts.join("\n")
  end

  def run_script(env, fname, task)
    case @mode
    when :persistent
      # Split the SQL into separate statements and execute them individually
      bash env, %(
      # Execute the combined SQL script with proper variable replacement
      cat #{fname} | sed 's|:_name_|#{task.output_stem}|g' | #{duckdb_cmd} | tee #{fname}.log
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
