require 'rubygems'
require 'rubygems/package'
require 'zlib'
require 'fileutils'

module Util
  module Tar
    # Creates a tar file in memory recursively
    # from the given path.
    #
    # Returns a StringIO whose underlying String
    # is the contents of the tar file.
    def tar(path)
      tarfile = StringIO.new('')
      Gem::Package::TarWriter.new(tarfile) do |tar|
        Dir[File.join(path, '**/*')].each do |file|
          mode = File.stat(file).mode
          relative_file = file.sub(/^#{Regexp.escape path}\/?/, '')

          if File.directory?(file)
            tar.mkdir relative_file, mode
          else
            tar.add_file relative_file, mode do |tf|
              File.open(file, 'rb') { |f| tf.write f.read }
            end
          end
        end
      end

      tarfile.rewind
      tarfile
    end

    # gzips the underlying string in the given StringIO,
    # returning a new StringIO representing the
    # compressed file.
    def gzip(tarfile)
      gz = StringIO.new('')
      z = Zlib::GzipWriter.new(gz)
      z.write tarfile.string
      z.close # this is necessary!

      # z was closed to write the gzip footer, so
      # now we need a new StringIO
      StringIO.new gz.string
    end

    # un-gzips the given IO, returning the
    # decompressed version as a StringIO
    def ungzip(tarfile)
      z = Zlib::GzipReader.new(tarfile)
      unzipped = StringIO.new(z.read)
      z.close
      unzipped
    end

    # untars the given IO into the specified
    # directory
    def untar(io, destination)
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = File.join destination, tarfile.full_name

          if tarfile.directory?
            FileUtils.mkdir_p destination_file
          else
            destination_directory = File.dirname(destination_file)
            FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)
            File.open destination_file, 'wb' do |f|
              f.print tarfile.read
            end
          end
        end
      end
    end
  end
end

class MergeIntegrationTest
  include Util::Tar

  # pids without druid: prefix
  def initialize(pids, fixture_dir)
    @pids = pids
    @fixture_dir = fixture_dir
  end

  def delete_objs
    @pids.map { |p| 'druid:' + p }.each do |pid|
      begin
        i = Dor::Item.find pid
        i.delete if i
      rescue
      end
    end
  end

  def load_foxml(delete = true)
    delete_objs if delete
    @pids.map {|p| File.join(@fixture_dir, "druid_#{p}.foxml.xml")}.each do |foxml|
      ActiveFedora::FixtureLoader.import_to_fedora foxml
    end
  end

  def untar_workspace
    @pids.each do |pid|
      dr = DruidTools::Druid.new 'druid:' + pid, Dor::Config.stacks.local_workspace_root
      dr.prune!
      dr.mkdir
      tarfile = File.open(File.join(@fixture_dir, "#{pid}.tgz"), 'rb')
      io = ungzip tarfile
      untar(io, dr.pathname.parent)
    end
  end

  def publish_shelve
    @pids.map {|p| "druid:#{p}"}.each do |pid|
      i = Dor::Item.find pid
      change_manifest = i.get_content_diff(:shelve)
      Dor::DigitalStacksService.shelve_to_stacks i.pid, change_manifest.file_sets(:added, :content)
      i.publish_metadata
    end
  end

  def merge
    druids = @pids.map {|p| "druid:#{p}"}
    Dor::MergeService.merge_into_primary druids.shift, druids
  end

end

#
# p_pid = 'druid:ps262bn7350'
# s_pid = 'druid:tw313dx4156'
#
# i = Dor::Item.find p_pid
# i.delete
# i = Dor::Item.find s_pid
# i.delete
# ActiveFedora::FixtureLoader.import_to_fedora Dir.glob('../frda/*.xml').first
# ActiveFedora::FixtureLoader.import_to_fedora Dir.glob('../frda/*.xml').last
#
# # retar workspace dirs
# [p_pid, s_pid].each do |pid|
#   dr = DruidTools::Druid.new pid, Dor::Config.stacks.local_workspace_root
#   dr.prune!
#   dr.mkdir
#   Dir.chdir dr.pathname.parent do |dir|
#     pid =~ /(\d{4})$/
#     exec "tar xvzf /home/lyberadmin/wmene/frda/#{$1}.tgz"
#   end
# end
#
#
# # Add content to stacks and purl for secondary
# i = Dor::Item.find s_pid
# i.publish_metadata
# Dor::DigitalStacksService.shelve_to_stacks s_pid, ['T0000001.jp2']
#
# ms = Dor::MergeService.new p_pid, [s_pid]
# ms.check_objects_editable
# ms.move_metadata_and_content
# ms.decommission_secondaries

# 2nd merge druids
# %w(fq996gt6655 pf986hr8937 xz522yc4008 zf307yb9756)
# pids = %w(fq996gt6655 pf986hr8937 xz522yc4008 zf307yb9756)
# mit = MergeIntegrationTest.new pids, '/home/lyberadmin/wmene/frda2'
