module Dor
  Dependencies = [
    'dor/config',
    'dor/exceptions',

    # ActiveFedora Classes
    'dor/base',
    'dor/item',
    'dor/admin_policy_object',
    'dor/workflow_object',

    # Services
    'dor/search_service',
    'dor/metadata_service',
    'dor/registration_service',
    'dor/suri_service',
    'dor/workflow_service',
    'dor/digital_stacks_service',
    'dor/druid_utils',
    'dor/sdr_ingest_service',
    'dor/cleanup_service',
    'dor/provenance_metadata_service'
  ]
  Dependencies.each { |f| require f }
  
  class << self
    
    def configure *args, &block
      Dor::Config.configure *args, &block
    end
    
    def reload!
      configuration = Dor::Config.to_hash
      temp_v = $-v
      $-v = nil
      begin
        Dependencies.collect { |f| load File.join(File.dirname(__FILE__), "#{f}.rb") }
      ensure
        $-v = temp_v
      end
      Dor::Config.configure { |config| config.deep_merge!(configuration) }
      Dor
    end
    
  end
end