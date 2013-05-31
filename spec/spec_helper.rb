$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'dor-services'
require 'ruby-debug'

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

Dor::Config.configure do
  workflow.url 'http://lyberservices-dev.stanford.edu/workflow'

  fedora do
    url 'https://fedoraAdmin:fedoraAdmin@dor-dev.stanford.edu/fedora'
    cert_file '/Users/wmene/dev/afsgit/lyberteam/etd-robots/config/certs/dlss-dev-test.crt'
    key_file '/Users/wmene/dev/afsgit/lyberteam/etd-robots/config/certs/dlss-dev-test.key'
    key_pass ''
  end

end
