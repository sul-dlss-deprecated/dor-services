# frozen_string_literal: true

module Dor
  # Merges contentMetadata from several objects into one.
  class FileMetadataMergeService
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    class << self
      # @param [Array<String>] secondary_druids ids of the secondary objects that will get their contentMetadata merged into this one
      def self.copy_file_resources(primary, secondary_druids)
        merge_service = FileMetadataMergeService.new primary, secondary_druids
        merge_service.copy_file_resources
      end
      deprecation_deprecate copy_file_resources: 'No longer used by any DLSS code'
    end

    def initialize(primary, secondary_druids)
      @pid = primary.pid
      content_metadata = primary.contentMetadata
      content_metadata.ng_xml_will_change!
      @primary_cm = content_metadata.ng_xml
      @secondary_druids = secondary_druids
    end

    # Appends contentMetadata file resources from the source objects to this object
    def copy_file_resources
      base_id = primary_cm.at_xpath('/contentMetadata/@objectId').value
      max_sequence = primary_cm.at_xpath('/contentMetadata/resource[last()]/@sequence').value.to_i

      secondary_druids.each do |src_pid|
        source_obj = Dor.find src_pid
        source_cm = source_obj.contentMetadata.ng_xml

        # Copy the resources from each source object
        source_cm.xpath('/contentMetadata/resource').each do |old_resource|
          max_sequence += 1
          resource_copy = old_resource.clone
          resource_copy['sequence'] = max_sequence.to_s

          # Append sequence number to each secondary filename, then
          # look for filename collisions with the primary object
          resource_copy.xpath('file').each do |secondary_file|
            secondary_file['id'] = SecondaryFileNameService.create(secondary_file['id'], max_sequence)

            if primary_cm.at_xpath("//file[@id = '#{secondary_file['id']}']")
              raise Dor::Exception, "File '#{secondary_file['id']}' from secondary object #{src_pid} already exist in primary object: #{pid}"
            end
          end

          if old_resource['type']
            resource_copy['id'] = "#{old_resource['type']}_#{max_sequence}"
          else
            resource_copy['id'] = "#{base_id}_#{max_sequence}"
          end

          lbl = old_resource.at_xpath 'label'
          resource_copy.at_xpath('label').content = "#{Regexp.last_match(1)} #{max_sequence}" if lbl && lbl.text =~ /^(.*)\s+\d+$/

          primary_cm.at_xpath('/contentMetadata/resource[last()]').add_next_sibling resource_copy
          attr_node = primary_cm.create_element 'attr', src_pid, name: 'mergedFromPid'
          resource_copy.first_element_child.add_previous_sibling attr_node
          attr_node = primary_cm.create_element 'attr', old_resource['id'], name: 'mergedFromResource'
          resource_copy.first_element_child.add_previous_sibling attr_node
        end
      end
    end
    deprecation_deprecate copy_file_resources: 'No longer used by any DLSS code'

    private

    attr_reader :secondary_druids, :primary_cm, :pid
  end
end
