$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'active_fedora'
require 'dor/base'
require 'dor/suri_service'
require 'dor/workflow_service'

Spec::Runner.configure do |config|
  
end

module Kernel
  # Suppresses warnings within a given block.
  def with_warnings_suppressed
    saved_verbosity = $-v
    $-v = nil
    yield
  ensure
    $-v = saved_verbosity
  end
end

def class_exists?(class_name)
  klass = Module.const_get(class_name)
  return klass.is_a?(Class)
rescue NameError
  return false
end


Rails = Object.new unless defined? Rails
# Rails = Object.new unless(class_exists? 'Rails')

require 'dor_config'

