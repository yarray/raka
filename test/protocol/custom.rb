# frozen_string_literal: true

require_relative '../../lib/raka/protocol'

# awk script protocol, the input is bound to the content of the auto input
class Awk
  def build(code, task)
    <<-SHELL
    cat #{task.input} | awk '#{code}' > #{task.name}
    SHELL
  end

  def run_script(env, fname, _)
    run_cmd(env, "bash #{fname}")
  end
end

creator :awk, Awk
