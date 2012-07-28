module Dor
  
  class VersionTag
    include Comparable
    
    attr_reader :major, :minor, :admin
    
    def <=>(anOther)
      diff = @major <=> anOther.major
      return diff if diff != 0
      diff = @minor <=> anOther.minor
      return diff if diff != 0
      @admin <=> anOther.admin
    end
    
    # @param [String] raw_tag the value of the tag attribute from a Version node
    def self.parse(raw_tag)
      unless(raw_tag =~ /(\d+)\.(\d+)\.(\d+)/)
        return nil
      end
      VersionTag.new $1, $2, $3
    end
    
    def initialize(maj, min, adm)
      @major = maj.to_i
      @minor = min.to_i
      @admin = adm.to_i
    end
    
    # @param [Symbol] sig which part of the version tag to increment
    #  :major, :minor, :admin
    def increment(sig)
      case sig
      when :major
        @major += 1
        @minor = 0
        @admin = 0
      when :minor
        @minor += 1
        @admin = 0
      when :admin
        @admin += 1
      end
      self
    end
    
    def to_s
      "#{@major.to_s}.#{@minor.to_s}.#{admin.to_s}"
    end
  end
  
  class VersionMetadataDS < ActiveFedora::NokogiriDatastream
    before_create :ensure_non_versionable
      
    set_terminology do |t|
      t.root(:path => "versionMetadata") 
      t.version do
        t.version_id :path => { :attribute => "versionID" }
        t.tag :path => { :attribute => "tag" }
        t.description
      end
    end

    # Default EventsDS xml 
    def self.xml_template
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.versionMetadata 
      end
      return builder.doc
    end

    def ensure_non_versionable
      self.versionable = "false"
    end
    
    def increment_version(description = nil, significance = nil)
      if( find_by_terms(:version).size == 0)
        v = ng_xml.create_element "version", 
          :versionId => '1', :tag => '1.0.0'
        d = ng_xml.create_element "description", "Initial Version"
        ng_xml.root['objectId'] = pid  
        ng_xml.root.add_child(v)
        v.add_child d
      else
        current = current_version
        current_id = current[:versionId].to_i
        current_tag = VersionTag.parse(current[:tag])
        
        v = ng_xml.create_element "version", :versionId => (current_id + 1).to_s
        if(significance && current_tag)
          v[:tag] = current_tag.increment(significance).to_s
        end
        ng_xml.root['objectId'] = pid  
        ng_xml.root.add_child(v)
        
        if(description)
          d = ng_xml.create_element "description", description
          v.add_child d
        end
      end
      self.dirty = true
    end
    
    def current_version
      versions = find_by_terms(:version)
      versions.max_by {|v| v[:versionId].to_i }
    end
    
    def newest_tag
      tags = find_by_terms(:version, :tag)
      tags.map{|t| VersionTag.parse(t.value)}.max
    end
    
    def update_current_version(opts = {})
      return if find_by_terms(:version).size == 1
      return if opts.empty?
      current = current_version
      if(opts.include? :description)
        d = current.at_xpath('description')
        if(d)
          d.content = opts[:description]
        else
          d_node = ng_xml.create_element "description", description
          current.add_child d
        end
      end
      if(opts.include? :significance)
        # tricky because if there is no tag, we have to find the newest
        if(current[:tag].nil?)
          current[:tag] = newest_tag.increment(opts[:significance]).to_s
        else
          # get rid of the current tag
          tags = find_by_terms(:version, :tag)
          sorted_tags = tags.map{|t| VersionTag.parse(t.value)}.sort
          current_tag = sorted_tags[sorted_tags.length - 2]           # Get the second greatest tag since we are dropping the current, greatest
          current[:tag] = current_tag.increment(opts[:significance]).to_s
        end
        
      end
    end
    
  end
    
end