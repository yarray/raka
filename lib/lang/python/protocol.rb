# frozen_string_literal: true

require_relative '../../protocol'

# shell(bash) protocol
class Python < LanguageProtocol
  def initialize(libs = [])
    libs = libs.map(&:to_s) # convert all to strings
    @imports = libs.map { |lib| "import #{lib}" }
    @imports.push('import pandas as pd') if libs.include? 'pandas'
    @imports.push('import numpy as np') if libs.include? 'numpy'
  end

  def build(code, _task)
    (@imports + [code]).join "\n"
  end

  def run_script_cmd(_env, fname, _task)
    "python #{fname}"
  end
end

creator :py, Python
