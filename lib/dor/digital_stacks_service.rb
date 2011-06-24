require 'tempfile'
require 'systemu'

module Dor
  class DigitalStacksService
    
    Config.declare(:stacks) do
  	  document_cache_storage_root nil
  	  document_cache_host nil
  	  document_cache_user nil
  	  
  	  storage_root '/stacks'
  	  host nil
  	  user nil
  	  
  	  local_workspace_root '/dor'
    end
    
    # TODO copied from lyber-core, but didn't want to create circular dependency for between gems for this one method
    # Executes a system command in a subprocess. 
    # The method will return stdout from the command if execution was successful.
    # The method will raise an exception if if execution fails. 
    # The exception's message will contain the explaination of the failure.
    # @param [String] command the command to be executed
    # @return [String] stdout from the command if execution was successful
    def self.execute(command)
      status, stdout, stderr = systemu(command)
      if (status.exitstatus != 0)
        raise stderr
      end
      return stdout
    rescue
      msg = "Command failed to execute: [#{command}] caused by <STDERR =\n#{stderr.split($/).join("\n")}>"
      msg << "\nSTDOUT =\n#{stdout.split($/).join("\n")}" if (stdout && (stdout.length > 0))
      raise msg
    end
    
    def self.druid_tree(druid)
      if(druid =~ /^druid:([a-z]{2})(\d{3})([a-z]{2})(\d{4})$/)
        return File.join($1, $2, $3, $4)
      else
        return nil
      end
    end
        
    def self.transfer_to_document_store(id, content, filename)
      path = self.druid_tree(id)
      raise "Invalid druid: #{id}" if(path.nil?)
      
      # create the remote directory in the document cache
      remote_document_cache_dir = File.join(Config.stacks.document_cache_storage_root, path)
      command = "ssh #{Config.stacks.document_cache_user}@#{Config.stacks.document_cache_host} mkdir -p #{remote_document_cache_dir}"
      self.execute(command)

      # create a temp file containing the content and copy the contents to the remote document cache
      Tempfile.open(filename) do |tf| 
        tf.write(content) 
        tf.flush
        command = "scp \"#{tf.path}\" #{Config.stacks.document_cache_user}@#{Config.stacks.document_cache_host}:#{remote_document_cache_dir}/#{filename}"
        self.execute(command)
      end
    end
    
    def self.shelve_to_stacks(id, files)
      path = self.druid_tree(id)
      raise "Invalid druid: #{id}" if(path.nil?)
      
      # create the remote directory on the digital stacks
      remote_storage_dir = File.join(Config.stacks.storage_root, path)
      command = "ssh #{Config.stacks.user}@#{Config.stacks.host} mkdir -p #{remote_storage_dir}"
      self.execute(command)

      # copy the contents for the given object from the local workspace directory to the remote directory
      local_storage_dir = File.join(Config.stacks.local_workspace_root, path)
      files.each do |file|
        command = "scp \"#{local_storage_dir}/#{file}\" #{Config.stacks.user}@#{Config.stacks.host}:#{remote_storage_dir}"
        self.execute(command)
      end
    end

  end

end

