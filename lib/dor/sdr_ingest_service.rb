require 'lyber-utils'

module Dor
  class SdrIngestService

    Config.declare(:sdr) do
  	  local_workspace_root '/dor/workspace'
      local_export_home '/dor/export'
      datastreams do
        contentMetadata 'required'
        descMetadata 'required'
        identityMetadata 'required'
        provenanceMetadata 'required'
        relationshipMetadata 'required'
        rightsMetadata 'optional'
        sourceMetadata 'optional'
      end
    end

    # Some boilerplace entries for the bagit metadata file
    METADATA_INFO =  {
        'Source-Organization' => 'Stanford University Libraries',
        'Stanford-Content-Metadata'  =>  'data/metadata/contentMetadata.xml',
        'Stanford-Identity-Metadata'  =>  'data/metadata/identityMetadata.xml',
        'Stanford-Provenance-Metadata'  =>  'data/metadata/provenanceMetadata.xml'
    }

    # Create a bagit object and fill it with content
    # Then tar it
    # @param [LyberCore::Robots::WorkItem]
    def self.transfer(dor_item, agreement_id)
      druid = dor_item.pid
      content_dir = Druid.new(druid).path(Config.sdr.local_workspace_root)

      # Create the bag
      bag_dir = File.join(Config.sdr.local_export_home, druid)
      export_bag = LyberUtils::BagitBag.new(bag_dir)

      # Fill the bag
      export_bag.add_content_files(content_dir, use_links=true)
      add_metadata_datastreams(dor_item, export_bag)
      export_bag.write_metadata_info(metadata_info(druid, agreement_id))
      export_bag.write_manifests()
      export_bag.validate()

      unless LyberUtils::FileUtilities.tar_object(bag_dir)
        raise 'Unable to tar the bag'
      end

      # Now bootstrap SDR workflow queue to start SDR robots
      Dor::WorkflowService.create_workflow('sdr', druid, 'sdrIngestWF', read_sdr_workflow_xml(), {:create_ds => false})
    end

    # Read in the XML file needed to initialize the SDR workflow
    # @return [String]
    def self.read_sdr_workflow_xml()
      return IO.read(File.join("#{ROBOT_ROOT}", "config", "workflows", "sdrIngestWF", "sdrIngestWF.xml"))
    end

    # For each of the metadata files or datastreams, create a file in in the bag's data/metadata folder
    # @param[String, LyberUtils::BagitBag]
    def self.add_metadata_datastreams(dor_item, export_bag)
      Config.sdr.datastreams.to_hash.each_pair do |ds_name, required|
        # ds_name in this context is a symbol, so convert it to a string
        filename = "#{ds_name.to_s}.xml"
        metadata_string = self.get_datastream_content(dor_item, ds_name.to_s, required)
        self.export_metadata_string(metadata_string, filename, export_bag) unless metadata_string.nil?
      end
    end

    # create a link to a metadata file in the bag's data/metadata folder
    def self.export_metadata_file(metadata_dir, filename, bag)
      metadata_file = File.join(metadata_dir, filename)
      bag_metadata_dir = File.join(bag.bag_dir, 'data', 'metadata')
      if (File.exist?(metadata_file))
        bag_file = File.join(bag_metadata_dir, filename)
        File.link(metadata_file, bag_file)
        return true
      else
        return false
      end
    end

    # return the content of the specied datastream if it exists
    # if non-existant, return nil or raise exception depending on value of required
    def self.get_datastream_content(dor_item, ds_name, required)
      ds = (ds_name == 'relationshipMetadata' ? 'RELS-EXT' : ds_name)
      if dor_item.datastream_names.include?(ds)
        return dor_item.datastreams[ds].content
      elsif (required == 'optional')
        return nil
      else
        raise "required datastream #{ds_name} not found in DOR"
      end
    end

    # create a file in the bag's data/metadata folder containing the metadata string
    # @param[String, String, LyberUtils::BagitBag]
    def self.export_metadata_string(metadata_string, filename, bag)
      bag.add_metadata_file_from_string(metadata_string, filename)
    end

    # merge item-specific data into the standard hash of metadata information
    # @param [String, String]
    def self.metadata_info(druid, agreement_id)
       item_info = {
              'External-Identifier' =>  druid,
              'Stanford-Agreement-ID'  =>  agreement_id
      }
      merged_info = item_info.merge(METADATA_INFO)
      return merged_info
    end

  end

end