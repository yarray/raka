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

  private

  def wrap_template(code)
    @script_template.gsub(/^\<code\>$/, code)
  end

  public

  def initialize(language_impl, script_template: '<code>')
    # contextual variables, will be passed later
    @impl = language_impl
    @script_template = script_template
    @block = nil
    @text = nil
  end

  # for syntax sugar like shell* <code text>
  def *(text)
    @text = text
    [self]
  end

  # a block::str -> str should be given to resolve the bindings in code text
  def call(env, task)
    code = yield @text if @text
    code = @block.call(task) if @block # do not resolve

    env.logger.debug code
    script_text = @impl.build(wrap_template(remove_common_indent(code)), task)
    temp_script = create_tmp(script_text)
    env.logger.debug temp_script
    @impl.run_script env, temp_script, task
    env.logger.debug script_text
  end
end

# A special language protocol, just a wrapper for action, pass block instead of
# string to execute
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

# helper functions to implement LanguageImpl
def run_cmd(env, cmd)
  Open3.popen3(cmd) do |_stdin, stdout, stderr, _thread|
    env.logger.debug(stdout.read)
    env.logger.info(stderr.read)
  end
end

def pick_kwargs(klass, kwargs)
  param_ref = klass.instance_method(:initialize).parameters
    .filter { |arg| arg.size == 2 && arg[0] == :key }
    .map { |arg| arg[1] }
  kwargs.filter do |key, _value|
    param_ref.include? key
  end
end

def creator(name, klass, global_defaults = {})
  global_config = global_defaults
  define_singleton_method name do |*args, **kwargs, &block|
    # pick keyword arguments for klass
    kwargs = global_config.merge kwargs
    impl = klass.new(*args, **pick_kwargs(klass, kwargs))
    proto = LanguageProtocol.new(impl, **pick_kwargs(LanguageProtocol, kwargs))
    if block
      proto.block = block
      [proto]
    else
      proto.define_singleton_method :config do |**config|
        global_config = global_defaults.merge config
      end
      proto # if no block, allow configure or waiting for * to add code text
    end
  end
end
