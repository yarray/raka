# frozen_string_literal: true

require_relative '../../protocol'

# r language protocol
class R
  def initialize(libs = [], **kwargs)
    @libs = libs
    super(**kwargs)
  end

  def build(code, _)
    libraries = @libs.map { |name| "suppressPackageStartupMessages(library(#{name}))" }

    [libraries, code].join "\n"
  end

  def run_script(env, fname, _task)
    env.send :sh, "Rscript #{fname}"
  end
end

creator :r, R
