require 'net/ssh'
require 'net/sftp'

module Dor
  class DigitalStacksService
    def self.druid_tree(druid)
      File.expand_path('..',DruidTools::Druid.new(druid,'/').path)
    rescue
      raise "Invalid druid: #{id}"
    end
        
    def self.transfer_to_document_store(id, content, filename)
      path = self.druid_tree(id)
      
      # create the remote directory in the document cache
      remote_document_cache_dir = File.join(Config.stacks.document_cache_storage_root, path)
      
      content_io = StringIO.new(content)
      Net::SFTP.start(Config.stacks.document_cache_host,Config.stacks.document_cache_user,:auth_methods=>['publickey']) do |sftp|
        sftp.session.exec! "mkdir -p #{remote_document_cache_dir}"
        sftp.upload!(content_io,File.join(remote_document_cache_dir,filename))
      end
    end

    def self.remove_from_stacks(id, files)
      path = self.druid_tree(id)

      remote_storage_dir = File.join(Config.stacks.storage_root, path)
      Net::SFTP.start(Config.stacks.host,Config.stacks.user,:auth_methods=>['publickey']) do |sftp|
        files.each { |file| sftp.remove!(File.join(remote_storage_dir,file)) }
      end
    end
    
    def self.rename_in_stacks(id, file_map)
      path = self.druid_tree(id)

      remote_storage_dir = File.join(Config.stacks.storage_root, path)
      Net::SFTP.start(Config.stacks.host,Config.stacks.user,:auth_methods=>['publickey']) do |sftp|
        file_map.each { |source,dest| sftp.rename!(File.join(remote_storage_dir,source),File.join(remote_storage_dir,dest)) }
      end
    end
    
    def self.shelve_to_stacks(id, files)
      path = self.druid_tree(id)

      druid = DruidTools::Druid.new(id,Config.stacks.local_workspace_root)
      remote_storage_dir = File.join(Config.stacks.storage_root, path)
      Net::SFTP.start(Config.stacks.host,Config.stacks.user,:auth_methods=>['publickey']) do |sftp|
        # create the remote directory on the digital stacks
        sftp.session.exec! "mkdir -p #{remote_storage_dir}"
        # copy the contents for the given object from the local workspace directory to the remote directory
        uploads = files.collect do |file| 
          local_file = druid.find_content(file)
          sftp.upload(local_file, File.join(remote_storage_dir,file))
        end
        uploads.each { |upload| upload.wait }
      end
    end

  end

end

