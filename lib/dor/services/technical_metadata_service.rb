# frozen_string_literal: true

require 'rubygems'
require 'moab/stanford'
require 'jhove_service'
require 'dor-services'

module Dor
  # Extracts technical metadata from files using JHOVE
  # If this is a new version it gets the old technicalMetadata datastream by
  # making an API call to sdr-services-app (via dor-services-app) and
  # only overwrites/adds parts for the files that were changed or added.
  # This allows us to avoid re-staging files that have not changed.
  # Switching to a more granular data model that has file metadata separate from
  # the Work metadata will allow us to simplify this greatly.
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
        final_techmd = build_technical_metadata(druid, merged_nodes)
      end
      ds = dor_item.datastreams['technicalMetadata']
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
          raise 'jhove-service dependency gem was not found.  Please add it to your Gemfile and run bundle install'
        end
      end
    end
    private_class_method :test_jhove_service

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [FileGroupDifference] The differences between two versions of a group of files
    def self.get_content_group_diff(dor_item)
      return Moab::FileGroupDifference.new if dor_item.contentMetadata.nil?
      raise Dor::ParameterError, 'Missing Dor::Config.stacks.local_workspace_root' if Config.stacks.local_workspace_root.nil?

      inventory_diff = Sdr::Client.get_content_diff(dor_item.pid, dor_item.contentMetadata.content, 'all')
      inventory_diff.group_difference('content')
    end
    private_class_method :get_content_group_diff

    # @param [FileGroupDifference] content_group_diff
    # @return [Hash<Symbol,Array>] Sets of filenames grouped by change type for use in performing file or metadata operations
    def self.get_file_deltas(content_group_diff)
      content_group_diff.file_deltas
    end
    private_class_method :get_file_deltas

    # @param [Hash<Symbol,Array>] deltas Sets of filenames grouped by change type for use in performing file or metadata operations
    # @return [Array<String>] The list of filenames for files that are either added or modifed since the previous version
    def self.get_new_files(deltas)
      deltas[:added] + deltas[:modified]
    end
    private_class_method :get_new_files

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object
    def self.get_old_technical_metadata(dor_item)
      sdr_techmd = get_sdr_technical_metadata(dor_item.pid)
      return sdr_techmd unless sdr_techmd.nil?

      get_dor_technical_metadata(dor_item)
    end
    private_class_method :get_old_technical_metadata

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object (fetched from SDR storage)
    #   The data is updated to the latest format.
    def self.get_sdr_technical_metadata(druid)
      sdr_techmd = get_sdr_metadata(druid, 'technicalMetadata')
      return sdr_techmd if sdr_techmd =~ /<technicalMetadata/
      return ::JhoveService.new.upgrade_technical_metadata(sdr_techmd) if sdr_techmd =~ /<jhove/

      nil
    end
    private_class_method :get_sdr_technical_metadata

    # @param [Dor::Item] dor_item The DOR item being processed by the technical metadata robot
    # @return [String] The technicalMetadata datastream from the previous version of the digital object (fetched from DOR fedora).
    #   The data is updated to the latest format.
    def self.get_dor_technical_metadata(dor_item)
      ds = 'technicalMetadata'
      return nil unless dor_item.datastreams.key?(ds) && !dor_item.datastreams[ds].new?

      dor_techmd = dor_item.datastreams[ds].content
      return dor_techmd if dor_techmd =~ /<technicalMetadata/
      return ::JhoveService.new.upgrade_technical_metadata(dor_techmd) if dor_techmd =~ /<jhove/

      nil
    end
    private_class_method :get_dor_technical_metadata

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @param [String] dsname The identifier of the metadata datastream
    # @return [String] The datastream contents from the previous version of the digital object (fetched from SDR storage)
    def self.get_sdr_metadata(druid, dsname)
      Sdr::Client.get_sdr_metadata(druid, dsname)
    end
    private_class_method :get_sdr_metadata

    # @param [DruidTools::Druid] druid A wrapper class for the druid identifier.  Used to generate paths
    # @param [Array<String>] new_files The list of filenames for files that are either added or modifed since the previous version
    # @return [String] The technicalMetadata datastream for the new files of the new digital object version
    def self.get_new_technical_metadata(druid, new_files)
      return nil if new_files.nil? || new_files.empty?

      workspace = DruidTools::Druid.new(druid, Dor::Config.sdr.local_workspace_root)
      content_dir = workspace.find_filelist_parent('content', new_files)
      temp_dir = workspace.temp_dir
      jhove_service = ::JhoveService.new(temp_dir)
      jhove_service.digital_object_id = druid
      fileset_file = write_fileset(temp_dir, new_files)
      jhove_output_file = jhove_service.run_jhove(content_dir, fileset_file)
      tech_md_file = jhove_service.create_technical_metadata(jhove_output_file)
      IO.read(tech_md_file)
    end
    private_class_method :get_new_technical_metadata

    # @param [Pathname]  temp_dir  The pathname of the temp folder in the object's workspace area
    # @param [Object] new_files [Array<String>] The list of filenames for files that are either added or modifed since the previous version
    # @return [Pathname] Save the new_files list to a text file and return that file's name
    def self.write_fileset(temp_dir, new_files)
      fileset_pathname = Pathname(temp_dir).join('jhove_fileset.txt')
      fileset_pathname.open('w') { |f| f.puts(new_files) }
      fileset_pathname
    end
    private_class_method :write_fileset

    # @param [String] old_techmd The technicalMetadata datastream from the previous version of the digital object
    # @param [String] new_techmd The technicalMetadata datastream for the new files of the new digital object version
    # @param [Array<String>] deltas The list of filenames for files that are either added or modifed since the previous version
    # @return [Hash<String,Nokogiri::XML::Node>] The complete set of technicalMetadata nodes for the digital object, indexed by filename
    def self.merge_file_nodes(old_techmd, new_techmd, deltas)
      old_file_nodes = get_file_nodes(old_techmd)
      new_file_nodes = get_file_nodes(new_techmd)
      merged_nodes = {}
      deltas[:identical].each do |path|
        merged_nodes[path] = old_file_nodes[path]
      end
      deltas[:modified].each do |path|
        merged_nodes[path] = new_file_nodes[path]
      end
      deltas[:added].each do |path|
        merged_nodes[path] = new_file_nodes[path]
      end
      deltas[:renamed].each do |oldpath, newpath|
        clone = old_file_nodes[oldpath].clone
        clone.sub!(/<file\s*id.*?["'].*?["'].*?>/, "<file id='#{newpath}'>")
        merged_nodes[newpath] = clone
      end
      deltas[:copyadded].each do |oldpath, newpath|
        clone = old_file_nodes[oldpath].clone
        clone.sub!(/<file\s*id.*?["'].*?["'].*?>/, "<file id='#{newpath}'>")
        merged_nodes[newpath] = clone
      end
      merged_nodes
    end
    private_class_method :merge_file_nodes

    # @param [String] technical_metadata A technicalMetadata datastream contents
    # @return [Hash<String,Nokogiri::XML::Node>] The set of nodes from a technicalMetadata datastream, indexed by filename
    def self.get_file_nodes(technical_metadata)
      file_hash = {}
      return file_hash if technical_metadata.nil?

      current_file = []
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
          current_file = []
          path = nil
          in_file = false
        elsif in_file
          current_file << line
        end
      end
      file_hash
    end
    private_class_method :get_file_nodes

    # @param [String] druid The identifier of the digital object being processed by the technical metadata robot
    # @param [Hash<String,Nokogiri::XML::Node>] merged_nodes The complete set of technicalMetadata nodes for the digital object, indexed by filename
    # @return [String] The finalized technicalMetadata datastream contents for the new object version
    def self.build_technical_metadata(druid, merged_nodes)
      techmd_root = +<<~EOF
        <technicalMetadata objectId='#{druid}' datetime='#{Time.now.utc.iso8601}'
            xmlns:jhove='http://hul.harvard.edu/ois/xml/ns/jhove'
            xmlns:mix='http://www.loc.gov/mix/v10'
            xmlns:textmd='info:lc/xmlns/textMD-v3'>
      EOF
      doc = techmd_root
      merged_nodes.keys.sort.each { |path| doc << merged_nodes[path] }
      doc + '</technicalMetadata>'
    end
    private_class_method :build_technical_metadata
  end
end
