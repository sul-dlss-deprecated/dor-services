module Dor
  class VersionTag
    include Comparable

    attr_reader :major, :minor, :admin

    def <=>(other)
      diff = @major <=> other.major
      return diff if diff != 0
      diff = @minor <=> other.minor
      return diff if diff != 0
      @admin <=> other.admin
    end

    # @param [String] raw_tag the value of the tag attribute from a Version node
    def self.parse(raw_tag)
      return nil unless raw_tag =~ /(\d+)\.(\d+)\.(\d+)/
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
      "#{@major}.#{@minor}.#{admin}"
    end
  end

  class VersionMetadataDS < ActiveFedora::OmDatastream
    before_create :ensure_non_versionable

    set_terminology do |t|
      t.root(:path => 'versionMetadata')
      t.version do
        t.version_id :path => { :attribute => 'versionID' }
        t.tag :path => { :attribute => 'tag' }
        t.description
      end
    end

    # Default EventsDS xml
    def self.xml_template
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.versionMetadata {
          xml.version(:versionId => '1', :tag => '1.0.0') {
            xml.description 'Initial Version'
          }
        }
      end
      builder.doc
    end

    def ensure_non_versionable
      self.versionable = 'false'
    end

    # @param [String] description optional text describing version change
    # @param [Symbol] significance optional which part of the version tag to increment
    #  :major, :minor, :admin (see VersionTag#increment)
    def increment_version(description = nil, significance = nil)
      if  find_by_terms(:version).size == 0
        v = ng_xml.create_element 'version',
        :versionId => '1', :tag => '1.0.0'
        d = ng_xml.create_element 'description', 'Initial Version'
        ng_xml.root['objectId'] = pid
        ng_xml.root.add_child(v)
        v.add_child d
      else
        current = current_version_node
        current_id = current[:versionId].to_i
        current_tag = VersionTag.parse(current[:tag])

        v = ng_xml.create_element 'version', :versionId => (current_id + 1).to_s
        if significance && current_tag
          v[:tag] = current_tag.increment(significance).to_s
        end
        ng_xml.root['objectId'] = pid
        ng_xml.root.add_child(v)

        if description
          d = ng_xml.create_element 'description', description
          v.add_child d
        end
      end
    end

    # @return [String] value of the most current versionId
    def current_version_id
      current_version = current_version_node
      if current_version.nil?
        return '1'
      else
        current_version[:versionId].to_s
      end
    end

    # @param [Hash] opts optional params
    # @option opts [String] :description describes the version change
    # @option opts [Symbol] :significance which part of the version tag to increment
    #  :major, :minor, :admin (see VersionTag#increment)
    def update_current_version(opts = {})
      ng_xml.root['objectId'] = pid
      return if find_by_terms(:version).size == 1
      return if opts.empty?
      current = current_version_node
      if opts.include? :description
        d = current.at_xpath('description')
        if d
          d.content = opts[:description]
        else
          d_node = ng_xml.create_element 'description', opts[:description]
          current.add_child d_node
        end
      end
      if opts.include? :significance
        # tricky because if there is no tag, we have to find the newest
        if current[:tag].nil?
          current[:tag] = newest_tag.increment(opts[:significance]).to_s
        else
          # get rid of the current tag
          tags = find_by_terms(:version, :tag)
          sorted_tags = tags.map {|t| VersionTag.parse(t.value)}.sort
          current_tag = sorted_tags[sorted_tags.length - 2]           # Get the second greatest tag since we are dropping the current, greatest
          current[:tag] = current_tag.increment(opts[:significance]).to_s
        end

      end
      self.content = ng_xml.to_s
    end

    # @return [Boolean] returns true if the current version has a tag and a description, false otherwise
    def current_version_closeable?
      current = current_version_node
      if current[:tag] && current.at_xpath('description')
        return true
      else
        return false
      end
    end

    # @return [String] The tag for the newest version
    def current_tag
      current_version_node[:tag].to_s
    end

    def tag_for_version(versionId)
      nodes = ng_xml.search('//version[@versionId=\'' + versionId + '\']')
      if nodes.length == 1
        nodes.first['tag'].to_s
      else
        ''
      end
    end

    # @return [String] The description for the specified version, or empty string if there is no description
    def description_for_version(versionId)
      nodes = ng_xml.search('//version[@versionId=\'' + versionId + '\']')
      if nodes.length == 1 && nodes.first.at_xpath('description')
        nodes.first.at_xpath('description').content.to_s
      else
        ''
      end
    end

    # @return [String] The description for the current version
    def current_description
      desc_node = current_version_node.at_xpath('description')
      return desc_node.content if desc_node
      ''
    end

    # Compares the current_version with the passed in known_version (usually SDRs version)
    #   If the known_version is greater than the current version, then all version nodes greater than the known_version are removed,
    #   then the current_version is incremented.  This repairs the case where a previous call to open a new verison
    #   updates the versionMetadata datastream, but versioningWF is not initiated.  Prevents the versions from getting
    #   out of synch with SDR
    #
    # @param [Integer] known_version object version you wish to synch to, usually SDR's version
    # @param [Hash] opts optional parameters
    # @option opts [String] :description describes the version change
    # @option opts [Symbol] :significance which part of the version tag to increment
    def sync_then_increment_version(known_version, opts = {})
      cv = current_version_id.to_i
      raise Dor::Exception.new("Cannot sync to a version greater than current: #{cv}, requested #{known_version}") if cv < known_version

      while cv != known_version &&
        current_version_node.remove
        cv = current_version_id.to_i
      end

      increment_version(opts[:description], opts[:significance])
    end

    private

    # @return [Nokogiri::XML::Node] Node representing the current version
    def current_version_node
      versions = find_by_terms(:version)
      versions.max_by {|v| v[:versionId].to_i }
    end

    def newest_tag
      tags = find_by_terms(:version, :tag)
      tags.map {|t| VersionTag.parse(t.value)}.max
    end

  end
end
