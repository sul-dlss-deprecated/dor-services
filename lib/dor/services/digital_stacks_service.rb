require 'net/ssh'
require 'net/sftp'

module Dor
  class DigitalStacksService

    def self.transfer_to_document_store(id, content, filename)
      druid = DruidTools::PurlDruid.new id, Config.stacks.local_document_cache_root
      druid.content_dir # create the druid tree if it doesn't exist yet
      File.open(File.join(druid.content_dir, filename), 'w') {|f| f.write content }
    end

    def self.remove_from_stacks(id, files)
      files.each do |file|
        dr = DruidTools::StacksDruid.new id, Config.stacks.local_stacks_root
        content = dr.find_content file
        FileUtils.rm content if content
      end
    end

    # @param [String] id object pid
    # @param [Array<Array<String>>] file_map an array of two string arrays.  Each inner array represents old-file/new-file mappings.  First string is the old file name, second string is the new file name. e.g:
    #   [ ['src1.file', 'dest1.file'], ['src2.file', 'dest2.file'] ]
    def self.rename_in_stacks(id, file_map)
      return if file_map.nil? or file_map.empty?
      dr = DruidTools::StacksDruid.new id, Config.stacks.local_stacks_root
      content_dir = dr.find_filelist_parent('content', file_map.first.first)
      file_map.each do |src, dest|
        File.rename(File.join(content_dir, src), File.join(content_dir, dest))
      end
    end

    def self.shelve_to_stacks(id, files)
      workspace_druid = DruidTools::Druid.new(id,Config.stacks.local_workspace_root)
      stacks_druid = DruidTools::StacksDruid.new(id,Config.stacks.local_stacks_root)
      files.each do |file|
        stacks_druid.content_dir
        workspace_file = workspace_druid.find_content(file)
        FileUtils.cp workspace_file, stacks_druid.content_dir
      end
    end

    # Assumes the digital stacks storage root is mounted to the local file system
    # TODO since this is delegating to the Druid, this method may not be necessary
    def self.prune_stacks_dir(id)
      stacks_druid_tree = DruidTools::StacksDruid.new(id, Config.stacks.local_stacks_root)
      stacks_druid_tree.prune!
    end

    def self.prune_purl_dir(id)
      druid = DruidTools::PurlDruid.new(id, Dor::Config.stacks.local_document_cache_root)
      druid.prune!
    end
  end

end
