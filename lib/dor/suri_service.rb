require 'rest-client'
require 'active_fedora'

module Dor
  class SuriService
    
    Config.declare(:suri) do
  	  url nil
  	  user nil
  	  pass nil
  	  id_namespace 'druid'
  	  mint_ids false
    end
    
    # If Dor::Config.suri.mint_ids is set to true, then this method
    # returns Config.suri.id_namespace:id_from_suri
    # Throws an exception if there were any problems
    def self.mint_id
      unless(Config.suri.mint_ids)
        return Fedora::Repository.instance.nextid
      end
      
      #Post with no body
      resource = RestClient::Resource.new("#{Config.suri.url}/suri2/namespaces/#{Config.suri.id_namespace}/identifiers",
                                :user => Config.suri.user, :password => Config.suri.pass)
      id = resource.post('').chomp

      return "#{Config.suri.id_namespace}:#{id.strip}"

#    rescue Exception => e
#      Rails.logger.error("Unable to mint id from suri: #{e.to_s}")
#      raise e
    end
  
    
  end
end