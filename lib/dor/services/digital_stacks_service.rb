require 'net/ssh'
require 'net/sftp'

module Dor

  class DigitalStacksService

    def self.transfer_to_document_store(id, content, filename)
      druid = DruidTools::PurlDruid.new id, Config.stacks.local_document_cache_root
      druid.content_dir # create the druid tree if it doesn't exist yet
      File.open(File.join(druid.content_dir, filename), 'w') { |f| f.write content }
    end

    # Delete files from stacks that have change type 'deleted', 'copydeleted', or 'modified'
    # @param [Pathname] stacks_object_pathname the stacks location of the digital object
    # @param [Moab::FileGroupDifference] content_diff the content file version differences report
    def self.remove_from_stacks(stacks_object_pathname, content_diff)
      [:deleted, :copydeleted, :modified].each do |change_type|
        subset = content_diff.subset(change_type) # {Moab::FileGroupDifferenceSubset
        subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
          moab_signature = moab_file.signatures.first # {Moab::FileSignature}
          file_pathname = stacks_object_pathname.join(moab_file.basis_path)
          if file_pathname.exist? and (file_pathname.size == moab_signature.size)
            file_signature = Moab::FileSignature.new.signature_from_file(file_pathname)
            file_pathname.delete if (file_signature == moab_signature)
          end
        end
      end
    end

    # Rename files from stacks that have change type 'renamed' using an intermediate temp filename.
    # The 2-step renaming allows chained or cyclic renames to occur without file collisions.
    # @param [Pathname] stacks_object_pathname the stacks location of the digital object
    # @param [Moab::FileGroupDifference] content_diff the content file version differences report
    def self.rename_in_stacks(stacks_object_pathname, content_diff)
      subset = content_diff.subset(:renamed) # {Moab::FileGroupDifferenceSubset

      # 1st Pass - rename files from original name to checksum-based name
      subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
        moab_signature = moab_file.signatures.first # {Moab::FileSignature}
        original_pathname = stacks_object_pathname.join(moab_file.basis_path)
        if original_pathname.exist? and (original_pathname.size == moab_signature.size)
          file_signature = Moab::FileSignature.new.signature_from_file(original_pathname)
          if (file_signature == moab_signature)
            temp_pathname = stacks_object_pathname.join(moab_signature.checksums.values.last)
            original_pathname.rename(temp_pathname)
          end
        end
      end

      # 2nd Pass - rename files from checksum-based name to new name
      subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
        moab_signature = moab_file.signatures.first # {Moab::FileSignature}
        temp_pathname = stacks_object_pathname.join(moab_signature.checksums.values.last)
        if temp_pathname.exist?
          new_pathname = stacks_object_pathname.join(moab_file.other_path)
          new_pathname.parent.mkpath
          temp_pathname.rename(new_pathname)
        end
      end

    end

    # Add files to stacks that have change type 'added', 'copyadded' or 'modified'.
    # @param [DruidTools::Druid] workspace_druid he dor workspace location of the digital object
    # @param [Pathname] stacks_object_pathname the stacks location of the digital object
    # @param [Moab::FileGroupDifference] content_diff the content file version differences report
    def self.shelve_to_stacks(workspace_druid, stacks_object_pathname, content_diff)
      [:added, :copyadded, :modified,].each do |change_type|
        subset = content_diff.subset(change_type) # {Moab::FileGroupDifferenceSubset
        subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
          moab_signature = moab_file.signatures.last # {Moab::FileSignature}
          filename = (change_type == :modified) ? moab_file.base_path : moab_file.other_path
          new_pathname = stacks_object_pathname.join(filename)
          if new_pathname.exist?
            file_signature = Moab::FileSignature.new.signature_from_file(new_pathname)
            new_pathname.delete if (file_signature != moab_signature)
          end
          unless new_pathname.exist?
            workspace_pathname = Pathname(workspace_druid.find_content(filename))
            FileUtils.cp workspace_pathname.to_s, stacks_object_pathname.to_s
          end
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

end
