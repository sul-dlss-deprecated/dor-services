require 'rubygems'
require 'lyber-utils'
require 'moab_stanford'
require 'dor-services'

module Dor
  class SdrIngestService

    def self.transfer(dor_item, agreement_id=nil)
      druid = dor_item.pid
      signature_catalog = get_signature_catalog(druid)

      workspace = DruidTools::Druid.new(druid,Dor::Config.sdr.local_workspace_root)
      metadata_dir = extract_datastreams(dor_item, workspace)

      new_version_id = signature_catalog.version_id + 1
      version_inventory = get_version_inventory(metadata_dir, druid, new_version_id)

      bag_dir = Pathname(Dor::Config.sdr.local_export_home).join(druid.sub('druid:',''))
      bagger = Moab::Bagger.new(version_inventory, signature_catalog, bag_dir)
      bagger.reset_bag
      bag_inventory = bagger.create_bag_inventory(:depositor)
      content_group = bag_inventory.group('content')
      content_dir = workspace.find_filelist_parent('content',content_group.path_list)
      signature_catalog.normalize_group_signatures(content_group, content_dir)
      bagger.deposit_group('content', content_dir)
      bagger.deposit_group('metadata', metadata_dir)
      bagger.create_tagfiles
      bagger.create_tarfile
      # Now bootstrap SDR workflow. but do not create the workflows datastream
      dor_item.initialize_workflow('sdrIngestWF', 'sdr', false)
    end

    def self.get_signature_catalog(druid)
      sdr_client = Dor::Config.sdr.rest_client
      url = "objects/#{druid}/manifest/signatureCatalog.xml"
      response = sdr_client[url].get
      Moab::SignatureCatalog.parse(response)
    rescue
      Moab::SignatureCatalog.new(:digital_object_id => druid, :version_id => 0)
    end

    def self.extract_datastreams(dor_item, workspace)
      metadata_dir = Pathname(workspace.path('metadata',create=true))
      Config.sdr.datastreams.to_hash.each_pair do |ds_name, required|
        ds_name = ds_name.to_s
        metadata_file = metadata_dir.join("#{ds_name}.xml")
        unless metadata_file.exist?
          metadata_string = self.get_datastream_content(dor_item, ds_name, required)
          metadata_file.open('w') { |f| f << metadata_string } if metadata_string
        end
      end
      metadata_dir
    end

    # return the content of the specied datastream if it exists
    # if non-existant, return nil or raise exception depending on value of required
    def self.get_datastream_content(dor_item, ds_name, required)
      ds = (ds_name == 'relationshipMetadata' ? 'RELS-EXT' : ds_name)
      if dor_item.datastreams.keys.include?(ds) and not dor_item.datastreams[ds].new?
        return dor_item.datastreams[ds].content
      elsif (required == 'optional')
        return nil
      else
        raise "required datastream #{ds_name} not found in DOR"
      end
    end

    def self.get_version_inventory(metadata_dir, druid, version_id)
      version_inventory = get_content_inventory(metadata_dir, druid, version_id)
      version_inventory.groups << get_metadata_file_group(metadata_dir)
      version_inventory
    end

    def self.get_content_inventory(metadata_dir, druid, version_id)
      content_metadata = metadata_dir.join('contentMetadata.xml').read
      content_inventory = Stanford::ContentInventory.new.inventory_from_cm(content_metadata, druid, subset='preserve', version_id)
      content_inventory
    end

    def self.get_metadata_file_group(metadata_dir)
      file_group = FileGroup.new(:group_id=>'metadata').group_from_directory(metadata_dir)
      file_group
    end

  end

end