# frozen_string_literal: true

require_relative '../protocol'

# r language protocol
class R
  def initialize(src, libs = [], **kwargs)
    @src = src
    @libs = libs
    super(**kwargs)
  end

  def build(code, _)
    libraries = ([
      :pipeR
    ] + @libs).map { |name| "suppressPackageStartupMessages(library(#{name}))" }

    sources = ["source('#{File.dirname(__FILE__)}/io.R')"] +
              (@src ? [@src] : []).map { |name| "source('#{SRC_DIR}/#{name}.R')" }

    extra = [
      '`|` <- `%>>%`',
      "conn_args <- list(host='#{HOST}', user='#{USER}', dbname='#{DB}', port='#{PORT}')",
      'args <- commandArgs(trailingOnly = T)',
      'sql_input    <- init_sql_input(conn_args, args[1])',
      'table_input  <- init_table_input(conn_args, args[1])',
      'table_output <- init_table_output(conn_args, args[1])'
    ]

    [libraries, sources, extra, code].join "\n"
  end

  def run_script(env, fname, task)
    env.send :sh, "Rscript #{fname} '#{task.scope || 'public'}'"
  end
end

creator :r, R
