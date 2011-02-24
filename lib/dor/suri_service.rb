require 'rest-client'
require 'active_fedora'

module Dor
  class SuriService
    
    # If Dor::Config[:mint_suri_ids] is set to true, then this method
    # returns Dor::Config[:id_namespace]:id_from_suri
    # Throws an exception if there were any problems
    def self.mint_id
      unless(Dor::Config[:mint_suri_ids])
        return Fedora::Repository.instance.nextid
      end
      
      #Post with no body
      resource = RestClient::Resource.new("#{Dor::Config[:suri_url]}/suri2/namespaces/#{Dor::Config[:id_namespace]}/identifiers",
                                :user => Dor::Config[:suri_user], :password => Dor::Config[:suri_pass])
      id = resource.post('').chomp

      return "#{Dor::Config[:id_namespace]}:#{id.strip}"

#    rescue Exception => e
#      Rails.logger.error("Unable to mint id from suri: #{e.to_s}")
#      raise e
    end
  
    
  end
end