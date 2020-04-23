# frozen_string_literal: true

require_relative '../../protocol'

COMMON_ALIASES = {
  pandas: :pd,
  numpy: :np
}.freeze

# Binding for python language, allow specifying imports and paths
class Python
  # @implements LanguageImpl
  def initialize(libs: [], paths: [])
    libs = libs.map(&:to_s) # convert all to strings
    @imports = libs.map { |lib| "import #{lib}" }
    COMMON_ALIASES.each do |name, short|
      @imports.push("import #{name} as #{short}") if libs.include? name.to_s
    end
    @paths = ['import sys'] + paths.map { |path| "sys.path.append('#{path}')" }
  end

  def build(code, _task)
    (@paths + @imports + [code]).join "\n"
  end

  def run_script(env, fname, _task)
    run_cmd(env, "python #{fname}")
  end
end

creator :py, Python
