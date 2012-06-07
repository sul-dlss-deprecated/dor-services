require 'net/ssh'
require 'net/sftp'

module Dor
  class DigitalStacksService
    def self.druid_tree(druid)
      Druid.new(druid).path
    rescue
      nil
    end
        
    def self.transfer_to_document_store(id, content, filename)
      path = self.druid_tree(id)
      raise "Invalid druid: #{id}" if(path.nil?)
      
      # create the remote directory in the document cache
      remote_document_cache_dir = File.join(Config.stacks.document_cache_storage_root, path)
      
      Net::SFTP.start(Config.stacks.document_cache_host,Config.stacks.document_cache_user,:auth_methods=>['publickey']) do |sftp|
        sftp.session.exec! "mkdir -p #{remote_document_cache_dir}"
        sftp.open!("#{remote_document_cache_dir}/#{filename}","w") do |rf|
          sftp.write!(rf[:handle],0,content)
          sftp.close!(rf[:handle])
        end
      end
    end
    
    def self.shelve_to_stacks(id, files)
      path = self.druid_tree(id)
      raise "Invalid druid: #{id}" if(path.nil?)
      
      local_storage_dir = File.join(Config.stacks.local_workspace_root, path)
      remote_storage_dir = File.join(Config.stacks.storage_root, path)
      Net::SFTP.start(Config.stacks.host,Config.stacks.user,:auth_methods=>['publickey']) do |sftp|
        # create the remote directory on the digital stacks
        sftp.session.exec! "mkdir -p #{remote_storage_dir}"
        # copy the contents for the given object from the local workspace directory to the remote directory
        files.each do |file|
          sftp.upload!("#{local_storage_dir}/#{file}", "#{remote_storage_dir}/#{file}")
        end
      end
    end

  end

end

