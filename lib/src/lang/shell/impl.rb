# frozen_string_literal: true

require_relative '../../protocol'

# shell(bash) protocol
class Shell
  # @implements LanguageImpl
  def build(code, _)
    ['set -e', code].join "\n"
  end

  def run_script(env, fname, _)
    run_cmd(env, "bash #{fname}")
  end
end

creator :shell, Shell
