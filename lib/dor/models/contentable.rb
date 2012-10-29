module Dor
  module Contentable
    extend ActiveSupport::Concern

    #add a file to a resource, not to be confused with add a resource to an object
    def add_file file, resource, file_name, mime_type=nil,publish='false', shelve='false', preserve='false'
      contentMD=self.datastreams['contentMetadata']
      xml=contentMD.ng_xml
      #make sure the resource exists
      if xml.search('//resource[@id=\''+resource+'\']').length == 0
        raise 'resource doesnt exist.'
      end
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(file_name)
      oldlocation=location.gsub('/'+self.pid.gsub('druid:',''),'')
      md5=Digest::MD5.file(file.path).hexdigest
      sha1=Digest::SHA1.file(file.path).hexdigest
      size=File.size?(file.path)
      #update contentmd
      file_hash={:name=>file_name,:md5 => md5, :publish=>publish, :shelve=> shelve, :preserve => preserve, :size=>size.to_s, :sha1=>sha1, :mime_type => mime_type}
      begin 
        request=sftp.stat!(location.gsub(file_name,''))
        begin
          request=sftp.stat!(location)
          raise 'The file '+file_name+' already exists!'
        rescue Net::SFTP::StatusException
          sftp.upload!(file.path,location)
          self.contentMetadata.add_file file_hash,resource
        end
      rescue Net::SFTP::StatusException 
        #the directory layout doesnt match the new style, so use the old style.
        begin
          request=sftp.stat!(oldlocation)
          raise 'The file '+file_name+' already exists!'
        rescue Net::SFTP::StatusException
          #the file doesnt already exist, which is good. Add it
          sftp.upload!(file.path,oldlocation)
          self.contentMetadata.add_file file_hash,resource
        end
      end
      #can only arrive at this point if a non status exception occurred.
    end

    def replace_file file,file_name
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      item=Dor::Item.find(self.pid)
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(file_name)
      oldlocation=location.gsub('/'+self.pid.gsub('druid:',''),'')

      md5=Digest::MD5.file(file.path).hexdigest
      sha1=Digest::SHA1.file(file.path).hexdigest
      size=File.size?(file.path)
      publish='false'
      preserve='false'
      shelve='false'
      #update contentmd
      file_hash={:name=>file_name,:md5 => md5, :publish=>publish, :shelve=> shelve, :preserve => preserve, :size=>size.to_s, :sha1=>sha1}
      begin 
        request=sftp.stat!(location)
        sftp.upload!(file.path,location)
        #this doesnt allow renaming files
        item.contentMetadata.update_file(file_hash, file_name)
      rescue 
        sftp.upload!(file.path,oldlocation)
        item.contentMetadata.update_file(file_hash, file_name)
      end
    end

    def get_file file
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(file)
      oldlocation=location.gsub('/'+file,'').gsub('/'+self.pid.gsub('druid:',''),'')+'/'+file
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      begin
        data=sftp.download!(location)
      rescue
        data=sftp.download!(oldlocation)
      end
    end
    def remove_file filename
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(filename)
      oldlocation=location.gsub('/'+self.pid.gsub('druid:',''),'')
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      begin
        data=sftp.remove!(location)
      rescue
        #if the file doesnt exist, that is ok, not all files will be present in the workspace
        begin
          data=sftp.remove!(oldlocation)
        rescue Net::SFTP::StatusException
        end
      end
      self.contentMetadata.remove_file filename
    end
    def rename_file old_name, new_name
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(old_name)
      oldlocation=location.gsub('/'+self.pid.gsub('druid:',''),'')
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      begin
        data=sftp.rename!(location,location.gsub(old_name,new_name))
      rescue
        data=sftp.rename!(oldlocation,oldlocation.gsub(old_name,new_name))
      end
      self.contentMetadata.rename_file(old_name, new_name)
    end
    def remove_resource resource_name
      #run delete for all of the files in the resource
      xml=self.contentMetadata.ng_xml
      files=xml.search('//resource[@id=\''+resource_name+'\']/file').each do |file|
        self.remove_file(file['id'])
      end
      #remove the resource record from the metadata and renumber the resource sequence
      self.contentMetadata.remove_resource resource_name       
    end
    #list files in the workspace
    def list_files
      filename='none'
      files=[]
      puts Config.content.content_server+Config.content.content_user
      sftp=Net::SFTP.start(Config.content.content_server,Config.content.content_user,:auth_methods=>['publickey']) 
      druid_tools=DruidTools::Druid.new(self.pid,Config.content.content_base_dir)
      location=druid_tools.path(filename).gsub(filename,'')
      oldlocation=location.gsub('/'+self.pid.gsub('druid:',''),'')
      begin
        sftp.dir.entries(location, "*") do |file|
          files<<file.name
        end
      rescue 
        begin
          sftp.dir.glob(oldlocation, "*") do |file|
            files<<file.name
          end
        rescue Net::SFTP::StatusException
          return files
        end
      end
      return files
    end
  end
end