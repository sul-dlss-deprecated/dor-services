module Dor
module Workflow
  class Process
    attr_reader :owner, :repo, :workflow
  
    def initialize(repo, workflow, attrs)
      @workflow = workflow
      @repo = repo
      if attrs.is_a? Nokogiri::XML::Node
        init_from_node(attrs)
      else
        @attrs = attrs
      end
    end

    def init_from_node(node)
      @attrs = {
        'name' => node['name'],
        'sequence' => node['sequence'] ? node['sequence'].to_i : nil,
        'status' => node['status'],    # TODO see how this affects argo
        'lifecycle' => node['lifecycle'],
        'label' => node.at_xpath('label/text()').to_s,
        'batch_limit' => node['batch-limit'] ? node['batch-limit'].to_i : nil,
        'error_limit' => node['error-limit'] ? node['error-limit'].to_i : nil,
        'prerequisite' => node.xpath('prereq').collect { |p| 
          repo = (p['repository'].nil? or p['repository'] == @repo) ? nil : p['repository']
          wf = (p['workflow'].nil? or p['workflow'] == @workflow) ? nil : p['workflow']
          [repo,wf,p.text.to_s].compact.join(':') 
        }
      }
    end
    
    def name          ; @attrs['name']          ; end
    def sequence      ; @attrs['sequence']      ; end
    def lifecycle     ; @attrs['lifecycle']     ; end
    def label         ; @attrs['label']         ; end
    def batch_limit   ; @attrs['batch_limit']   ; end
    def error_limit   ; @attrs['error_limit']   ; end
    def error_message ; @attrs['errorMessage']  ; end
    def prerequisite  ; @attrs['prerequisite']  ; end
    def status        ; @attrs['status']        ; end

    def completed?    ; self.status == 'completed' ; end
    def error?        ; self.status == 'error'     ; end
    def waiting?      ; self.status == 'waiting'   ; end

    def ready?
      self.waiting? and (not self.prerequisite.nil?) and self.prerequisite.all? { |pr| (prq = self.owner[pr]) && prq.completed? }
    end
    
    def blocked?
      self.waiting? and (not self.prerequisite.nil?) and self.prerequisite.any? { |pr| (prq = self.owner[pr]) && (prq.error? or prq.blocked?) }
    end
    
    def state
      if blocked?
        'blocked'
      elsif ready?
        'ready'
      else
        status
      end
    end
    
    def attempts
      @attrs['attempts'].to_i
    end
    
    def datetime
      @attrs['datetime'] ? Time.parse(@attrs['datetime']) : nil
    end
    
    def elapsed
      @attrs['elapsed'].nil? ? nil : @attrs['elapsed'].to_f
    end
        
    def update!(info, new_owner=nil)
      @owner = new_owner unless new_owner.nil?
      if info.is_a? Nokogiri::XML::Node
        info = Hash[info.attributes.collect { |k,v| [k,v.value] }]
      end
      @attrs.merge! info
    end
    
    def to_hash
      @attrs.reject { |k,v| v.nil? or v == 0 or (v.respond_to?(:empty?) and v.empty?) }
    end
  end
end
end