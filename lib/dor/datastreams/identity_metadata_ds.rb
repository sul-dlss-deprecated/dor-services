# frozen_string_literal: true

module Dor
  # Object identity and source metadata
  class IdentityMetadataDS < ActiveFedora::OmDatastream
    include SolrDocHelper

    # ids for previous and current catkeys
    CATKEY_TYPE_ID = 'catkey'
    PREVIOUS_CATKEY_TYPE_ID = 'previous_catkey'
    BARCODE_TYPE_ID = 'barcode'

    set_terminology do |t|
      t.root(path: 'identityMetadata')
      t.objectId   index_as: [:symbol]
      t.objectType index_as: [:symbol]
      t.objectLabel
      t.citationCreator
      t.sourceId
      t.otherId(path: 'otherId') do
        t.name_(path: { attribute: 'name' })
      end
      t.agreementId index_as: %i[stored_searchable symbol]
      t.tag index_as: [:symbol]
      t.citationTitle
      t.objectCreator index_as: %i[stored_searchable symbol]
      t.adminPolicy   index_as: [:not_searchable]
    end

    define_template :value do |builder, name, value, attrs|
      builder.send(name.to_sym, value, attrs)
    end

    def self.xml_template
      Nokogiri::XML('<identityMetadata/>')
    end

    def add_value(name, value, attrs = {})
      ng_xml_will_change!
      add_child_node(ng_xml.root, :value, name, value, attrs)
    end

    def objectId
      find_by_terms(:objectId).text
    end

    def sourceId
      node = find_by_terms(:sourceId).first
      node ? [node['source'], node.text].join(':') : nil
    end
    alias source_id sourceId

    # @param  [String, Nil] value The value to set or a nil/empty string to delete sourceId node
    # @return [String, Nil] The same value, as per Ruby convention for assignment operators
    # @note The actual values assigned will have leading/trailing whitespace stripped.
    def sourceId=(value)
      ng_xml_will_change!
      node = find_by_terms(:sourceId).first
      unless value.present? # so setting it to '' is the same as removal: worth documenting maybe?
        node&.remove
        return nil
      end
      parts = value.split(':', 2).map(&:strip)
      raise ArgumentError, "Source ID must follow the format 'namespace:value', not '#{value}'" unless
        parts.length == 2 && parts[0].present? && parts[1].present?

      node ||= ng_xml.root.add_child('<sourceId/>').first
      node['source'] = parts[0]
      node.content = parts[1]
    end
    alias source_id= sourceId=

    def otherId(type = nil)
      result = find_by_terms(:otherId).to_a
      if type.nil?
        result.collect { |n| [n['name'], n.text].join(':') }
      else
        result.select { |n| n['name'] == type }.collect(&:text)
      end
    end

    # @param [Array<String>] values
    def other_ids=(values)
      values.each { |value| add_otherId(value) }
    end

    def add_otherId(other_id)
      ng_xml_will_change!
      (name, val) = other_id.split(/:/, 2)
      node = ng_xml.root.add_child('<otherId/>').first
      node['name'] = name
      node.content = val
      node
    end

    def add_other_Id(type, val)
      raise 'There is an existing entry for ' + type + ', consider using update_other_Id().' if otherId(type).length > 0

      add_otherId(type + ':' + val)
    end

    def update_other_Id(type, new_val, val = nil)
      ng_xml.search('//otherId[@name=\'' + type + '\']')
            .select { |node| val.nil? || node.content == val }
            .each { ng_xml_will_change! }
            .each { |node| node.content = new_val }
            .any?
    end

    def remove_other_Id(type, val = nil)
      ng_xml.search('//otherId[@name=\'' + type + '\']')
            .select { |node| val.nil? || node.content == val }
            .each { ng_xml_will_change! }
            .each(&:remove)
            .any?
    end

    # Convenience method to get the current catkey
    # @return [String] current catkey value (or nil if none found)
    def catkey
      otherId(CATKEY_TYPE_ID).first
    end

    # Convenience method to set the catkey
    # @param  [String] val the new source identifier
    # @return [String] same value, as per Ruby assignment convention
    def catkey=(val)
      # if there was already a catkey in the record, store that in the "previous" spot (assuming there is no change)
      add_otherId("#{PREVIOUS_CATKEY_TYPE_ID}:#{catkey}") if val != catkey && !catkey.blank?

      if val.blank? # if we are setting the catkey to blank, remove the node from XML
        remove_other_Id(CATKEY_TYPE_ID)
      elsif catkey.blank? # if there is no current catkey, then add it
        add_other_Id(CATKEY_TYPE_ID, val)
      else # if there is a current catkey, update the current catkey to the new value
        update_other_Id(CATKEY_TYPE_ID, val)
      end

      val
    end

    # Convenience method to get the previous catkeys (will be an array)
    # @return [Array] previous catkey values (empty array if none found)
    def previous_catkeys
      otherId(PREVIOUS_CATKEY_TYPE_ID)
    end

    def barcode
      otherId(BARCODE_TYPE_ID).first
    end

    # Convenience method to set the barcode
    # @param  [String] val the new barcode
    # @return [String] same value, as per Ruby assignment convention
    def barcode=(val)
      if val.blank? # if we are setting the barcode to blank, remove the node from XML
        remove_other_Id(BARCODE_TYPE_ID)
      elsif barcode.blank? # if there is no current barcode, then add it
        add_other_Id(BARCODE_TYPE_ID, val)
      else # if there is a current barcode, update the current barcode to the new value
        update_other_Id(BARCODE_TYPE_ID, val)
      end

      val
    end

    # Helper method to get the release tags as a nodeset
    # @return [Nokogiri::XML::NodeSet] all release tags and their attributes
    def release_tags
      release_tags = ng_xml.xpath('//release')
      return_hash = {}
      release_tags.each do |release_tag|
        hashed_node = release_tag_node_to_hash(release_tag)
        if !return_hash[hashed_node[:to]].nil?
          return_hash[hashed_node[:to]] << hashed_node[:attrs]
        else
          return_hash[hashed_node[:to]] = [hashed_node[:attrs]]
        end
      end
      return_hash
    end

    private

    # Convert one release element into a Hash
    # @param rtag [Nokogiri::XML::Element] the release tag element
    # @return [Hash{:to, :attrs => String, Hash}] in the form of !{:to => String :attrs = Hash}
    def release_tag_node_to_hash(rtag)
      to = 'to'
      release = 'release'
      when_word = 'when' # TODO: Make to and when_word load from some config file instead of hardcoded here
      attrs = rtag.attributes
      return_hash = { to: attrs[to].value }
      attrs.tap { |a| a.delete(to) }
      attrs[release] = rtag.text.casecmp('true') == 0 # save release as a boolean
      return_hash[:attrs] = attrs

      # convert all the attrs beside :to to strings, they are currently Nokogiri::XML::Attr
      (return_hash[:attrs].keys - [to]).each do |a|
        return_hash[:attrs][a] = return_hash[:attrs][a].to_s if a != release
      end

      return_hash[:attrs][when_word] = Time.parse(return_hash[:attrs][when_word]) # convert when to a datetime
      return_hash
    end
  end # class
end
