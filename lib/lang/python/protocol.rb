# frozen_string_literal: true

require_relative '../../protocol'

COMMON_ALIASES = {
  pandas: :pd,
  numpy: :np
}.freeze

class Python
  # @implements LanguageImpl
  def initialize(libs: [])
    libs = libs.map(&:to_s) # convert all to strings
    @imports = libs.map { |lib| "import #{lib}" }
    COMMON_ALIASES.each do |name, short|
      @imports.push("import #{name} as #{short}") if libs.include? name.to_s
    end
  end

  def build(code, _task)
    (@imports + [code]).join "\n"
  end

  def run_script(env, fname, _task)
    run_cmd(env, "python #{fname}")
  end
end

creator :py, Python
