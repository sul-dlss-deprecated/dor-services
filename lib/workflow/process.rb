module Workflow
  class Process
    attr_reader :repository, :workflow
  
    def initialize(repository, workflow, attrs)
      @workflow = workflow
      @repository = repository
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
        'lifecycle' => node['lifecycle'],
        'label' => node.at_xpath('label/text()').to_s,
        'batch_limit' => node['batch-limit'] ? node['batch-limit'].to_i : nil,
        'error_limit' => node['error-limit'] ? node['error-limit'].to_i : nil,
        'prerequisite' => node.xpath('prereq').collect { |p| 
          repo = (p['repository'].nil? or p['repository'] == @repository) ? nil : p['repository']
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
    def prerequisite  ; @attrs['prerequisite']  ; end
    def status        ; @attrs['status']        ; end

    def attempts
      @attrs['attempts'].to_i
    end
    
    def datetime
      @attrs['datetime'] ? Time.parse(@attrs['datetime']) : nil
    end
    
    def elapsed
      @attrs['elapsed'].to_f
    end
        
    def update!(info)
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