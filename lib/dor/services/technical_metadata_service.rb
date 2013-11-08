require 'rubygems'
require 'moab_stanford'
require 'jhove_service'
require 'dor-services'

module Dor

  class TechnicalMetadataService

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [Boolean] True if technical metadata is correctly added or updated
    def self.add_update_technical_metadata(dor_item)
      test_jhove_service
      druid = dor_item.pid
      content_group_diff = get_content_group_diff(dor_item)
      deltas = get_file_deltas(content_group_diff)
      new_files = get_new_files(deltas)
      old_techmd = get_old_technical_metadata(dor_item)
      new_techmd = get_new_technical_metadata(druid, new_files)
      if old_techmd.nil?
        # this is version 1 or previous technical metadata was not saved
        final_techmd = new_techmd
      elsif content_group_diff.difference_count == 0
        # there have been no changes to content files from previous version
        return true
      else
        merged_nodes = merge_file_nodes(old_techmd, new_techmd, deltas)
        final_techmd = build_technical_metadata(druid,merged_nodes)
      end
      ds = dor_item.datastreams["technicalMetadata"]
      ds.dsLabel = 'Technical Metadata'
      ds.content = final_techmd
      ds.save
      true
    end

    # @return [Boolean] Make sure that the jhove-service gem is loaded
    def self.test_jhove_service
      unless defined? ::JhoveService
        begin
          require 'jhove_service'
        rescue LoadError => e
          puts e.inspect
          raise "jhove-service dependency gem was not found.  Please add it to your Gemfile and run bundle install"
        end
      end
    end

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [FileGroupDifference] The differences between two versions of a group of files
    def self.get_content_group_diff(dor_item)
      inventory_diff_xml = dor_item.get_content_diff('all')
      inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml)
      content_group_diff = inventory_diff.group_difference("content")
      content_group_diff
    end

    # @param [FileGroupDifference] content_group_diff
    # @return [Hash<Symbol,Array>] Sets of filenames grouped by change type for use in performing file or metadata operations
    def self.get_file_deltas(content_group_diff)
      deltas = content_group_diff.file_deltas
      deltas
    end

    # @param [Hash<Symbol,Array>] deltas Sets of filenames grouped by change type for use in performing file or metadata operations
    # @return [Array<String>] The list of filenames for files that are either added or modifed since the previous version
    def self.get_new_files(deltas)
      deltas[:added] + deltas[:modified]
    end

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object
    def self.get_old_technical_metadata(dor_item)
      sdr_techmd = get_sdr_technical_metadata(dor_item.pid)
      return sdr_techmd unless sdr_techmd.nil?
      get_dor_technical_metadata(dor_item)
    end

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object (fetched from SDR storage)
    #   The data is updated to the latest format.
    def self.get_sdr_technical_metadata(druid)
      begin
        sdr_techmd = get_sdr_metadata(druid, "technicalMetadata")
      rescue RestClient::ResourceNotFound => e
        return nil
      end
      if sdr_techmd =~ /<technicalMetadata/
        return sdr_techmd
      elsif sdr_techmd =~ /<jhove/
        return ::JhoveService.new.upgrade_technical_metadata(sdr_techmd)
      else
        return nil
      end
    end

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object (fetched from DOR fedora).
    #   The data is updated to the latest format.
    def self.get_dor_technical_metadata(dor_item)
      ds = "technicalMetadata"
      if dor_item.datastreams.keys.include?(ds) and not dor_item.datastreams[ds].new?
        dor_techmd = dor_item.datastreams[ds].content
      else
        return nil
      end
      if dor_techmd =~ /<technicalMetadata/
        return dor_techmd
      elsif dor_techmd =~ /<jhove/
        return ::JhoveService.new.upgrade_technical_metadata(dor_techmd)
      else
        return nil
      end
    end

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @param [String] dsname The identifier of the metadata datastream
    # @return [String] The datastream contents from the previous version of the digital object (fetched from SDR storage)
    def self.get_sdr_metadata(druid, dsname)
      sdr_client = Dor::Config.sdr.rest_client
      url = "objects/#{druid}/metadata/#{dsname}.xml"
      response = sdr_client[url].get
      response
    end

    # @param [DruidTools::Druid] druid_tool A wrapper class for the druid identifier.  Used to generate paths
    # @param [Array<String>] new_files The list of filenames for files that are either added or modifed since the previous version
    # @return [String] The technicalMetadata datastream for the new files of the new digital object version
    def self.get_new_technical_metadata(druid, new_files)
      return nil if new_files.nil? or new_files.empty?
      workspace = DruidTools::Druid.new(druid, Dor::Config.sdr.local_workspace_root)
      content_dir = workspace.find_filelist_parent('content',new_files)
      temp_dir = workspace.temp_dir
      jhove_service = ::JhoveService.new(temp_dir)
      jhove_service.digital_object_id=druid
      fileset_file = write_fileset(temp_dir, new_files)
      jhove_output_file = jhove_service.run_jhove(content_dir, fileset_file)
      tech_md_file = jhove_service.create_technical_metadata(jhove_output_file)
      IO.read(tech_md_file)
    end

    # @param [Pathname]  temp_dir  The pathname of the temp folder in the object's workspace area
    # @param [Object] new_files [Array<String>] The list of filenames for files that are either added or modifed since the previous version
    # @return [Pathname] Save the new_files list to a text file and return that file's name
    def self.write_fileset(temp_dir, new_files)
      fileset_pathname = Pathname(temp_dir).join('jhove_fileset.txt')
      fileset_pathname.open('w') {|f| f.puts(new_files) }
      fileset_pathname
    end

    # @param [String] old_techmd The technicalMetadata datastream from the previous version of the digital object
    # @param [String] new_techmd The technicalMetadata datastream for the new files of the new digital object version
    # @param [Array<String>] deltas The list of filenames for files that are either added or modifed since the previous version
    # @return [Hash<String,Nokogiri::XML::Node>] The complete set of technicalMetadata nodes for the digital object, indexed by filename
    def self.merge_file_nodes(old_techmd, new_techmd, deltas)
      old_file_nodes = get_file_nodes(old_techmd)
      new_file_nodes = get_file_nodes(new_techmd)
      merged_nodes = Hash.new
      deltas[:identical].each do |path|
        merged_nodes[path] = old_file_nodes[path]
      end
      deltas[:modified].each do |path|
        merged_nodes[path] = new_file_nodes[path]
      end
      deltas[:added].each do |path|
        merged_nodes[path] = new_file_nodes[path]
      end
      deltas[:renamed].each do |oldpath,newpath|
        clone = old_file_nodes[oldpath].clone
        clone.sub!(/<file\s*id.*?["'].*?["'].*?>/, "<file id='#{newpath}'>")
        merged_nodes[newpath] = clone
      end
      deltas[:copyadded].each do |oldpath,newpath|
        clone = old_file_nodes[oldpath].clone
        clone.sub!(/<file\s*id.*?["'].*?["'].*?>/, "<file id='#{newpath}'>")
        merged_nodes[newpath] = clone
      end
      merged_nodes
    end

    # @param [String] technical_metadata A technicalMetadata datastream contents
    # @return [Hash<String,Nokogiri::XML::Node>] The set of nodes from a technicalMetadata datastream , indexed by filename
    def self.get_file_nodes(technical_metadata)
      file_hash = Hash.new
      return file_hash if technical_metadata.nil?
      current_file = Array.new
      path = nil
      in_file = false
      technical_metadata.each_line do |line|
        if line =~ /^\s*<file.*["'](.*?)["']/
          current_file << line
          path = $1
          in_file = true
        elsif line =~ /^\s*<\/file>/
          current_file << line
          file_hash[path] = current_file.join
          current_file = Array.new
          path = nil
          in_file = false
        elsif in_file
          current_file << line
        end
      end
      file_hash
    end

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @param [Hash<String,Nokogiri::XML::Node>] merged_nodes The complete set of technicalMetadata nodes for the digital object, indexed by filename
    # @return [String] The finalized technicalMetadata datastream contents for the new object version
    def self.build_technical_metadata(druid, merged_nodes)
      techmd_root = <<-EOF
<technicalMetadata objectId='#{druid}' datetime='#{Time.now.utc.iso8601}'
    xmlns:jhove='http://hul.harvard.edu/ois/xml/ns/jhove'
    xmlns:mix='http://www.loc.gov/mix/v10'
    xmlns:textmd='info:lc/xmlns/textMD-v3'>
      EOF
      doc = techmd_root
      merged_nodes.keys.sort.each {|path| doc << merged_nodes[path] }
      doc << "</technicalMetadata>"
      doc
    end

  end

end

