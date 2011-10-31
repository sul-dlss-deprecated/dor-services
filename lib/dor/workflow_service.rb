require 'rest-client'

module Dor
  
  # Methods to create and update workflow
  #
  # ==== Required Constants
  # - Dor::CREATE_WORKFLOW : true or false.  Can be used to turn of workflow in a particular environment, like development
  # - Dor::WF_URI : The URI to the workflow service.  An example URI is 'http://lyberservices-dev.stanford.edu/workflow'
  module WorkflowService

    Config.declare(:workflow) { url nil }
  
    class << self
      # Creates a workflow for a given object in the repository.  If this particular workflow for this objects exists,
      # it will replace the old workflow with wf_xml passed to this method.  You have the option of creating a datastream or not.     
      # Returns true on success.  Caller must handle any exceptions
      #
      # == Parameters
      # - <b>repo</b> - The repository the object resides in.  The service recoginzes "dor" and "sdr" at the moment
      # - <b>druid</b> - The id of the object
      # - <b>workflow_name</b> - The name of the workflow you want to create
      # - <b>wf_xml</b> - The xml that represents the workflow
      # - <B>opts</b> - Options Hash where you can set
      #       :create_ds - If true, a workflow datastream will be created in Fedora.  Set to false if you do not want a datastream to be created
      #   If you do not pass in an <b>opts</b> Hash, then :create_ds is set to true by default
      # 
      def create_workflow(repo, druid, workflow_name, wf_xml, opts = {:create_ds => true})
        workflow_resource["#{repo}/objects/#{druid}/workflows/#{workflow_name}"].put(wf_xml, :content_type => 'application/xml', 
                                                                                     :params => {'create-ds' => opts[:create_ds] })
        return true
      end
  
      # Updates the status of one step in a workflow.      
      # Returns true on success.  Caller must handle any exceptions
      #
      # == Required Parameters
      # - <b>repo</b> - The repository the object resides in.  The service recoginzes "dor" and "sdr" at the moment
      # - <b>druid</b> - The id of the object
      # - <b>workflow_name</b> - The name of the workflow 
      # - <b>status</b> - The status that you want to set.  Typical statuses are 'waiting', 'completed', 'error', but could be any string
      # 
      # == Optional Parameters
      # - <b>elapsed</b> - The number of seconds it took to complete this step. Can have a decimal.  Is set to 0 if not passed in.
      # - <b>lifecycle</b> - Bookeeping label for this particular workflow step.  Examples are: 'registered', 'shelved'
      #
      # == Http Call
      # The method does an HTTP PUT to the URL defined in Dor::WF_URI.  As an example:
      #   PUT "/dor/objects/pid:123/workflows/GoogleScannedWF/convert"
      #   <process name=\"convert\" status=\"completed\" />"
      def update_workflow_status(repo, druid, workflow, process, status, elapsed = 0, lifecycle = nil)
        xml = create_process_xml(:name => process, :status => status, :elapsed => elapsed.to_s, :lifecycle => lifecycle)
        workflow_resource["#{repo}/objects/#{druid}/workflows/#{workflow}/#{process}"].put(xml, :content_type => 'application/xml')
        return true
      end
  
      #
      # Retrieves the process status of the given workflow for the given object identifier
      #
      def get_workflow_status(repo, druid, workflow, process)
        workflow_md = workflow_resource["#{repo}/objects/#{druid}/workflows/#{workflow}"].get
        doc = Nokogiri::XML(workflow_md)
        raise Exception.new("Unable to parse response:\n#{workflow_md}") if(doc.root.nil?)
    
        status = doc.root.at_xpath("//process[@name='#{process}']/@status").content
        return status
      end
  
      def get_workflow_xml(repo, druid, workflow)
        workflow_resource["#{repo}/objects/#{druid}/workflows/#{workflow}"].get
      end    

      # Updates the status of one step in a workflow to error.      
      # Returns true on success.  Caller must handle any exceptions
      #
      # == Required Parameters
      # - <b>repo</b> - The repository the object resides in.  The service recoginzes "dor" and "sdr" at the moment
      # - <b>druid</b> - The id of the object
      # - <b>workflow_name</b> - The name of the workflow 
      # - <b>error_msg</b> - The error message.  Ideally, this is a brief message describing the error
      # 
      # == Optional Parameters
      # - <b>error_txt</b> - A slot to hold more information about the error, like a full stacktrace
      #
      # == Http Call
      # The method does an HTTP PUT to the URL defined in Dor::WF_URI.  As an example:
      #   PUT "/dor/objects/pid:123/workflows/GoogleScannedWF/convert"
      #   <process name=\"convert\" status=\"error\" />"
      def update_workflow_error_status(repo, druid, workflow, process, error_msg, error_txt = nil)
        xml = create_process_xml(:name => process, :status => 'error', :errorMessage => error_msg, :errorText => error_txt)
        workflow_resource["#{repo}/objects/#{druid}/workflows/#{workflow}/#{process}"].put(xml, :content_type => 'application/xml')
        return true
      end
      
      # Returns the Date for a requested milestone from workflow lifecycle
      # @param [String] repo epository name
      # @param [String] druid object id
      # @param [String] milestone name of the milestone being queried for
      # @return [Time] when the milestone was achieved.  Returns nil if the milestone does not exist
      # @example_lifecycle_xml An example lifecycle xml from the workflow service. 
      #   <lifecycle objectId="druid:ct011cv6501">
      #     <milestone date="2010-04-27T11:34:17-0700">registered</milestone>
      #     <milestone date="2010-04-29T10:12:51-0700">inprocess</milestone>
      #     <milestone date="2010-06-15T16:08:58-0700">released</milestone>
      #   </lifecycle>
      def get_lifecycle(repo, druid, milestone)
        doc = self.query_lifecycle(repo, druid)
        milestone = doc.at_xpath("//lifecycle/milestone[text() = '#{milestone}']")
        if(milestone)
          return Time.parse(milestone['date'])
        end
          
        nil
      end
      
      def get_milestones(repo, druid)
        doc = self.query_lifecycle(repo, druid)
        doc.xpath("//lifecycle/milestone").collect do |node|
          { :milestone => node.text, :at => Time.parse(node['date']) }
        end
      end
      
#      private
      def create_process_xml(params)
        builder = Nokogiri::XML::Builder.new do |xml|
          attrs = params.reject { |k,v| v.nil? }
          xml.process(attrs)
        end
        return builder.to_xml
      end

      def query_lifecycle(repo, druid)
        lifecycle_xml = '<lifecycle/>'
        begin
          lifecycle_xml = workflow_resource["#{repo}/objects/#{druid}/lifecycle"].get
        rescue RestClient::ResourceNotFound
        end
        return Nokogiri::XML(lifecycle_xml)
      end
      
      def workflow_resource
        RestClient::Resource.new(Config.workflow.url,
        :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Config.fedora.cert_file)),
        :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Config.fedora.key_file), Config.fedora.key_pass))
      end
    end
  end
end
