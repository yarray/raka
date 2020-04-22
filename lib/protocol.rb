# frozen_string_literal: true

require 'securerandom'
require 'open3'

def remove_common_indent(code)
  code.gsub(/^#{code.scan(/^[ \t]+(?=\S)/).min}/, '')
end

def create_tmp(content)
  tmpfile = "/tmp/#{SecureRandom.uuid}"

  File.open(tmpfile, 'w') do |f|
    f.write content
  end

  tmpfile
end

# protocol conforms the interface:
#
# call(env, task) resolve
#
# call :: rake's main -> dsl task(see compiler) -> void
# resolve :: str -> str

# There are two methods to provide code to a language protocol, either a string literal
# OR a ruby block. Cannot choose both.
class LanguageProtocol
  attr_writer :block

  def initialize(script_template: '<code>')
    # contextual variables, will be passed later
    @block = nil
    @text = nil
    @script_template = script_template
  end

  # for syntax sugar like shell* <code text>
  def *(text)
    @text = text
    [self]
  end

  def wrap_template(code)
    @script_template.gsub(/^\<code\>$/, code)
  end

  # a block::str -> str should be given to resolve the bindings in code text
  def call(env, task)
    code = yield @text if @text
    code = @block.call(task) if @block # do not resolve

    env.logger.debug code
    script_text = build(wrap_template(remove_common_indent(code)), task)
    run_script env, create_tmp(script_text), task
  end

  # template methods:
  # build(code, task)
  def build(code, _)
    code
  end

  # run_script(env, fname, tas)
  def run_script(env, *args)
    Open3.popen3(run_script_cmd(env, *args)) do |_stdin, stdout, stderr, _thread|
      env.logger.debug(stdout.read)
      env.logger.debug(stderr.read)
    end
  end

  # run_script_cmd(env, fname, task)
  # can override thise only to use standard stdout & sterr suppressing, etc.
end

def creator(name, klass)
  define_singleton_method name do |*args, **kwargs, &block|
    res = klass.new(*args, **kwargs)
    if block
      res.block = block
      [res]
    else
      res # if no block, waiting for * to add code text
    end
  end
end

# A special protocol, just a wrapper for action, pass block instead of string to execute
# named RubyP to avoid name collision
class RubyP
  def initialize(&block)
    @block = block
  end

  def call(_, task, &resolve)
    @block.call(task, &resolve)
    FileUtils.touch(task.name)
  end
end

# use run instead of "ruby" to avoid name collision
def run(&block)
  [RubyP.new(&block)]
end
