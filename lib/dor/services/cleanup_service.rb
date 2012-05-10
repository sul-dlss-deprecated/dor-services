require 'fileutils'
require 'lyber-utils'

module Dor
  class CleanupService
    # Delete all workspace and export entities for the druid
    # @param [LyberCore::Robots::WorkItem]
    def self.cleanup(dor_item)
      druid = dor_item.pid
      workspace_dir = DruidTools::Druid.new(druid,Config.cleanup.local_workspace_root).path
      self.remove_entry(workspace_dir)
      bag_dir = File.join(Config.cleanup.local_export_home, druid)
      self.remove_entry(bag_dir)
      tarfile = "#{bag_dir}.tar"
      self.remove_entry(tarfile)
    end

    # Deleta a filesystem entry
    # @param [String]
    def self.remove_entry(entry)
      FileUtils.remove_entry(entry) if File.exist?(entry)
    end


  end

end