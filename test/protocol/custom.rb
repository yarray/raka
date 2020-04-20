# frozen_string_literal: true

require_relative '../../lib/protocol'

# awk script protocol, the input is bound to the content of the auto input
class Awk < LanguageProtocol
  def initialize; end

  def build(code, task)
    <<-SHELL
    cat #{task.input} | awk '#{code}' > #{task.name}
    SHELL
  end

  def run_script(env, fname, _)
    env.send :sh, "bash #{fname}", verbose: env.logger.level == Logger::DEBUG
  end
end

creator :awk, Awk
