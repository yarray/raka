# frozen_string_literal: true

require_relative '../../protocol'

# shell(bash) protocol
class Shell < LanguageProtocol
  def initialize(base_dir = './')
    @base_dir = base_dir
  end

  def build(code, _)
    ["cd #{@base_dir}", 'set -e', code].join "\n"
  end

  def run_script(env, fname, _)
    env.send :sh, "bash #{fname}", verbose: env.logger.level == Logger::DEBUG
  end
end

creator :shell, Shell
