# frozen_string_literal: true

require_relative '../../protocol'

# shell(bash) protocol
class Python < LanguageProtocol
  def initialize(libs = [])
    @imports = libs.map { |lib| "import #{lib}" }
    @imports.push('import pandas as pd') if libs.include? 'pandas'
    @imports.push('import numpy as np') if libs.include? 'numpy'
  end

  def build(code, _)
    (@imports + [code]).join "\n"
  end

  def run_script(env, fname, _)
    env.send :sh, "python #{fname}", verbose: env.logger.level == Logger::DEBUG
  end
end

creator :py, Python
