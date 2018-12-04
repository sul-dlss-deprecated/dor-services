# frozen_string_literal: true

module Dor
  module Contentable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    # add a file to a resource, not to be confused with add a resource to an object
    def add_file(file, resource, file_name, mime_type = nil, publish = 'no', shelve = 'no', preserve = 'no')
      xml = datastreams['contentMetadata'].ng_xml
      # make sure the resource exists
      raise 'resource doesnt exist.' if xml.search('//resource[@id=\'' + resource + '\']').length == 0

      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(file_name)
      oldlocation = location.gsub('/' + pid.gsub('druid:', ''), '')
      md5  = Digest::MD5.file(file.path).hexdigest
      sha1 = Digest::SHA1.file(file.path).hexdigest
      size = File.size?(file.path)
      # update contentmd
      file_hash = { name: file_name, md5: md5, publish: publish, shelve: shelve, preserve: preserve, size: size.to_s, sha1: sha1, mime_type: mime_type }
      begin
        sftp.stat!(location.gsub(file_name, ''))
        begin
          sftp.stat!(location)
          raise "The file #{file_name} already exists!"
        rescue Net::SFTP::StatusException
          sftp.upload!(file.path, location)
          contentMetadata.add_file file_hash, resource
        end
      rescue Net::SFTP::StatusException
        # directory layout doesn't match the new style, so use the old style.
        begin
          sftp.stat!(oldlocation)
          raise "The file #{file_name} already exists!"
        rescue Net::SFTP::StatusException
          # file doesn't already exist, which is good. Add it
          sftp.upload!(file.path, oldlocation)
          contentMetadata.add_file file_hash, resource
        end
      end
      # can only arrive at this point if a non status exception occurred.
    end
    deprecation_deprecate add_file: 'will be removed without replacement'

    def replace_file(file, file_name)
      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      item = Dor.find(pid)
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(file_name)
      oldlocation = location.gsub('/' + pid.gsub('druid:', ''), '')
      md5  = Digest::MD5.file(file.path).hexdigest
      sha1 = Digest::SHA1.file(file.path).hexdigest
      size = File.size?(file.path)
      # update contentmd
      file_hash = { name: file_name, md5: md5, size: size.to_s, sha1: sha1 }
      begin
        sftp.stat!(location)
        sftp.upload!(file.path, location)
        # this doesnt allow renaming files
        item.contentMetadata.update_file(file_hash, file_name)
      rescue StandardError
        sftp.upload!(file.path, oldlocation)
        item.contentMetadata.update_file(file_hash, file_name)
      end
    end
    deprecation_deprecate replace_file: 'will be removed without replacement'

    def get_preserved_file(file, version)
      Sdr::Client.get_preserved_file_content(pid, file, version)
    end
    deprecation_deprecate get_preserved_file: 'use dor-services-app/v1/sdr/objects/:druid/content/:filename instead'

    def get_file(file)
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(file)
      oldlocation = location.gsub('/' + file, '').gsub('/' + pid.gsub('druid:', ''), '') + '/' + file
      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      begin
        data = sftp.download!(location)
      rescue StandardError
        data = sftp.download!(oldlocation)
      end
      data
    end
    deprecation_deprecate get_file: 'use dor-services-app:/v1/objects/:id/contents/*path instead'

    # @param [String] filename
    def remove_file(filename)
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(filename)
      oldlocation = location.gsub('/' + pid.gsub('druid:', ''), '')
      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      begin
        sftp.remove!(location)
      rescue StandardError
        # if the file doesnt exist, that is ok, not all files will be present in the workspace
        begin
          sftp.remove!(oldlocation)
        rescue Net::SFTP::StatusException
        end
      end
      contentMetadata.remove_file filename
    end
    deprecation_deprecate remove_file: 'will be removed without replacement'

    # @param [String] old_name
    # @param [String] new_name
    def rename_file(old_name, new_name)
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(old_name)
      oldlocation = location.gsub('/' + pid.gsub('druid:', ''), '')
      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      begin
        sftp.rename!(location, location.gsub(old_name, new_name))
      rescue StandardError
        sftp.rename!(oldlocation, oldlocation.gsub(old_name, new_name))
      end
      contentMetadata.rename_file(old_name, new_name)
    end
    deprecation_deprecate rename_file: 'will be removed without replacement'

    # @param [String] resource_name ID of the resource elememnt
    def remove_resource(resource_name)
      # run delete for all of the files in the resource
      contentMetadata.ng_xml.search('//resource[@id=\'' + resource_name + '\']/file').each do |file|
        remove_file(file['id'])
      end
      # remove the resource record from the metadata and renumber the resource sequence
      contentMetadata.remove_resource resource_name
    end
    deprecation_deprecate remove_resource: 'will be removed without replacement'

    # TODO: Move to Argo
    # list files in the workspace
    # @return [Array] workspace files
    def list_files
      filename = 'none'
      files = []
      sftp = Net::SFTP.start(Config.content.content_server, Config.content.content_user, auth_methods: ['publickey'])
      druid_tools = DruidTools::Druid.new(pid, Config.content.content_base_dir)
      location = druid_tools.path(filename).gsub(filename, '')
      oldlocation = location.gsub('/' + pid.gsub('druid:', ''), '')
      begin
        sftp.dir.entries(location, '*') do |file|
          files << file.name
        end
      rescue StandardError
        begin
          sftp.dir.glob(oldlocation, '*') do |file|
            files << file.name
          end
        rescue Net::SFTP::StatusException
          return files
        end
      end
      files
    end
    deprecation_deprecate list_files: 'use dor-services-app:/v1/objects/:id/contents instead'

    # @param [String] filename
    # @return [Boolean] whether the file in question is present in the object's workspace
    def is_file_in_workspace?(filename)
      druid_obj = DruidTools::Druid.new(pid, Dor::Config.stacks.local_workspace_root)
      !druid_obj.find_content(filename).nil?
    end
    deprecation_deprecate is_file_in_workspace?: 'will be removed without replacement'

    # Clears RELS-EXT relationships, sets the isGovernedBy relationship to the SDR Graveyard APO
    # @param [String] tag optional String of text that is concatenated to the identityMetadata/tag "Decommissioned : "
    def decommission(tag)
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

    # TODO: Move to Dor-Utils.
    # Adds a RELS-EXT constituent relationship to the given druid
    # @param [String] druid the parent druid of the constituent relationship
    #   e.g.: <fedora:isConstituentOf rdf:resource="info:fedora/druid:hj097bm8879" />
    def add_constituent(druid)
      add_relationship :is_constituent_of, ActiveFedora::Base.find(druid)
    end
  end
end
