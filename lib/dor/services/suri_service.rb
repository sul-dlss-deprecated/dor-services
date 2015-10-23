require 'rest-client'
require 'active_fedora'

module Dor
  class SuriService
    # If Dor::Config.suri.mint_ids is set to true, then this method
    # returns Config.suri.id_namespace:id_from_suri
    # Throws an exception if there were any problems
    def self.mint_id quantity = nil
      want_array = quantity.is_a?(Numeric)
      quantity = 1 if quantity.nil?
      ids = []
      if Config.suri.mint_ids
        #Post with no body
        resource = RestClient::Resource.new("#{Config.suri.url}/suri2/namespaces/#{Config.suri.id_namespace}",
                                  :user => Config.suri.user, :password => Config.suri.pass)
        ids = resource["identifiers?quantity=#{quantity}"].post('').chomp.split(/\n/).collect { |id| "#{Config.suri.id_namespace}:#{id.strip}" }
      else
        repo = ActiveFedora::Base.respond_to?(:connection_for_pid) ? ActiveFedora::Base.connection_for_pid(0) : ActiveFedora.fedora.connection
        resp = Nokogiri::XML(repo.next_pid :numPIDs => quantity)
        ids = resp.xpath('/pidList/pid').collect { |node| node.text }
      end
      want_array ? ids : ids.first

#    rescue Exception => e
#      Rails.logger.error("Unable to mint id from suri: #{e.to_s}")
#      raise e
    end


  end
end
