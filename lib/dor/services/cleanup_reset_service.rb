require 'pathname'

module Dor

  # Remove all traces of the object's data files from the workspace and export areas
  class CleanupResetService
    
    # @param [String] druid The identifier for the object whose renamed data is to be removed
    # @return [void] remove copy of the renamed data that was exported to preservation core
    def self.cleanup_by_renamed_druid(druid)
      last_version = get_druid_last_version(druid) 
      cleanup_renamed_workspace_content(druid, last_version, Config.cleanup.local_workspace_root)
      cleanup_renamed_workspace_content(druid, last_version, Config.cleanup.local_assembly_root)
      cleanup_renamed_export(druid, last_version)
    end
    
    def self.get_druid_last_version(druid)
      druid_obj = Dor::Item.find(druid)
      last_version = druid_obj.current_version.to_i
      
      #if the current version is still open, avoid this versioned directory
      if Dor::WorkflowService.get_lifecycle('dor', druid, 'accessioned').nil? then 
        last_version = last_version - 1 
      end
    end
    
    # @param [String] druid The identifier for the object whose renamed data is to be removed
    # @param [String] base The base directory to delete from
    # @param [Integer] last_version The last version that the data should be removed until version 1
    # @return [void] remove all the object's renamed data files from the workspace area equal to less than the last_version
    def self.cleanup_renamed_workspace_content(druid,last_version, base)
      base_druid = DruidTools::Druid.new(druid, base)
      base_druid_tree = base_druid.pathname.to_s
      #if it is truncated tree /aa/111/aaa/1111/content, 
      #we should follow the regular cleanup technique

      renamed_directories = get_renamed_dir_list(last_version, base_druid_tree)
      renamed_directories.each do |path| 
        FileUtils.rm_rf(path)
      end
      base_druid.prune_ancestors(base_druid.pathname.parent)
    end
    
    
    # @param [String] druid The identifier for the object whose renamed data is to be removed
    # @param [String] base The base directory to delete from
    # @param [Integer] last_version The last version that the data should be removed until version 1
    # @return [void] prepares a list of renamed directories that should be removed
    def self.get_renamed_dir_list(last_version, base_druid_tree)
      renamed_directories = []    
      for i in 1..last_version 
        renamed_path = "#{base_druid_tree}_v#{i}"
        renamed_directories.append(renamed_path) if File.exists?(renamed_path) 
      end
      return renamed_directories      
    end

    # @param [String] druid The identifier for the object whose renamed bags data is to be removed
    # @return [void] remove copy of the renamed data that was exported to preservation core
    def self.cleanup_renamed_export(druid, last_version)
      id = druid.split(':').last
      base_bag_directory = File.join(Config.cleanup.local_export_home, id)
      
      bag_dir_list = get_renamed_bag_dir_list(last_version, base_bag_directory)
      bag_dir_list.each do |bag_dir| 
        Pathname(bag_dir).rmtree
      end
      
      bag_tar_list = get_renamed_bag_tar_list(last_version, base_bag_directory)
      bag_tar_list.each do |bag_tar| 
        Pathname(bag_tar).rmtree
      end
    end
    
    # @param [Integer] last_version The last version that the data should be removed until version 1
    # @param [String] base_bag_directory The base bag directory including the export home and druid id
    # @return [void] prepares a list of renamed bag directories that should be removed
    def self.get_renamed_bag_dir_list(last_version, base_bag_directory)
      renamed_bags = []    
      for i in 1..last_version do
        renamed_path = "#{base_bag_directory}_v#{i}"
        renamed_bags.append(renamed_path) if File.exists?(renamed_path) 
      end
      return renamed_bags      
    end

    # @param [String] base_bag_directory The base bag directory including the export home and druid id
    # @param [Integer] last_version The last version that the data should be removed until version 1
    # @return [void] prepares a list of renamed bag tars that should be removed
    def self.get_renamed_bag_tar_list(last_version, base_bag_directory)
      renamed_bags = []    
      for i in 1..last_version do
        renamed_path = "#{base_bag_directory}_v#{i}.tar"
        renamed_bags.append(renamed_path)  if File.exists?(renamed_path) 
      end
      return renamed_bags      
    end

  end
end
