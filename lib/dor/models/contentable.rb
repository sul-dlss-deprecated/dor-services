module Dor
  module Contentable
    extend ActiveSupport::Concern

    #add a file to a resource, not to be confused with add a resource to an object
    def add_file file, resource, file_name, mime_type=nil,publish='no', shelve='no', preserve='no'
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
      #update contentmd
      file_hash={:name=>file_name,:md5 => md5, :size=>size.to_s, :sha1=>sha1}
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

    def get_preserved_file file, version
      preservation_server=Config.content.sdr_server+'/sdr/objects/'+self.pid+"/content/"
      file=URI.encode(file)
      add=preservation_server+file+"?version="+version
      uri = URI(add)
      req = Net::HTTP::Get.new(uri.request_uri)
      req.basic_auth Config.content.sdr_user, Config.content.sdr_pass
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') {|http|
        http.request(req)
      }
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

    # Appends contentMetadata file resources from the source objects to this object
    # @param [Array<String>] source_obj_pids ids of the secondary objects that will get their contentMetadata merged into this one
    def copy_file_resources source_obj_pids
      primary_cm = contentMetadata.ng_xml
      base_id = primary_cm.at_xpath('/contentMetadata/@objectId').value
      max_sequence = primary_cm.at_xpath('/contentMetadata/resource[last()]/@sequence').value.to_i

      source_obj_pids.each do |src_pid|
        source_obj = Dor::Item.find src_pid
        source_cm = source_obj.contentMetadata.ng_xml

        # Copy the resources from each source object
        source_cm.xpath('/contentMetadata/resource').each do |old_resource|
          max_sequence += 1
          resource_copy = old_resource.clone
          resource_copy['sequence'] = "#{max_sequence}"

          # Append sequence number to each secondary filename, then
          # look for filename collisions with the primary object
          resource_copy.xpath('file').each do |secondary_file|
            secondary_file['id'] = new_secondary_file_name(secondary_file['id'], max_sequence)

            if primary_cm.at_xpath("//file[@id = '#{secondary_file["id"]}']")
              raise Dor::Exception.new "File '#{secondary_file['id']}' from secondary object #{src_pid} already exist in primary object: #{self.pid}"
            end
          end

          if old_resource['type']
            resource_copy['id'] = "#{old_resource['type']}_#{max_sequence}"
          else
            resource_copy['id'] = "#{base_id}_#{max_sequence}"
          end

          lbl = old_resource.at_xpath 'label'
          if lbl && lbl.text =~ /^(.*)\s+\d+$/
            resource_copy.at_xpath('label').content = "#{$1} #{max_sequence}"
          end

          primary_cm.at_xpath('/contentMetadata/resource[last()]').add_next_sibling resource_copy
          attr_node = primary_cm.create_element 'attr', src_pid, :name => 'mergedFromPid'
          resource_copy.first_element_child.add_previous_sibling attr_node
          attr_node = primary_cm.create_element 'attr', old_resource['id'], :name => 'mergedFromResource'
          resource_copy.first_element_child.add_previous_sibling attr_node
        end
      end
      self.contentMetadata.content_will_change!
    end

    def new_secondary_file_name old_name, sequence_num
      if old_name =~ /^(.*)\.(.*)$/
        return "#{$1}_#{sequence_num}.#{$2}"
      else
        return "#{old_name}_#{sequence_num}"
      end
    end

    # Clears RELS-EXT relationships, sets the isGovernedBy relationship to the SDR Graveyard APO
    # @param [String] tag optional String of text that is concatenated to the identityMetadata/tag "Decomissioned : "
    def decomission tag = nil
      # remove isMemberOf and isMemberOfCollection relationships
      clear_relationship :is_member_of
      clear_relationship :is_member_of_collection
      # remove isGovernedBy relationship
      clear_relationship :is_governed_by
      # add isGovernedBy to graveyard APO druid:sw909tc7852
      # SEARCH BY dc title for 'SDR Graveyard'
      add_relationship :is_governed_by, ActiveFedora::Base.find(Dor::SearchService.sdr_graveyard_apo_druid)
      # eliminate contentMetadata. set it to <contentMetadata/> ?
      contentMetadata.content = '<contentMetadata/>'
      # eliminate rightsMetadata. set it to <rightsMetadata/> ?
      rightsMetadata.content = '<rightsMetadata/>'
      add_tag "Decommissioned : #{tag}"
    end
  end
end