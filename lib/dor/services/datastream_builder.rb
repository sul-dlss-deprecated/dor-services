# frozen_string_literal: true

module Dor
  # The ContentMetadata and DescMetadata robot are allowed to build the
  # datastream by reading a file from the /dor/workspace that matches the
  # datastream name. This allows assembly or pre-assembly to prebuild the
  # datastreams from templates or using other means
  # (like the assembly-objectfile gem) and then have those datastreams picked
  # up and added to the object during accessionWF.
  #
  # This class builds that datastream using the content of a file if such a file
  # exists and is newer than the object's current datastream (see above); otherwise,
  # builds the datastream by calling build_fooMetadata_datastream.
  class DatastreamBuilder
    # @param [ActiveFedora::Base] object The object that contains the datastream
    # @param [ActiveFedora::Datastream] datastream The datastream object
    # @param [Boolean] force Should we overwrite existing datastream?
    # @param [Boolean] required If set to true, raise an error if we can't build the datastream
    # @return [ActiveFedora::Datastream]
    def initialize(object:, datastream:, force: false, required: false)
      @object = object
      @datastream = datastream
      @force = force
      @required = required
      @filename = find_metadata_file
    end

    def build
      # See if datastream exists as a file and if the file's timestamp is newer than datastream's timestamp.
      if file_newer_than_datastream?
        create_from_file(filename)
      elsif force || empty_datastream?
        create_default
      end
      # Check for success.
      raise "Required datastream #{datastream_name} could not be populated!" if required && empty_datastream?
    end

    private

    attr_reader :datastream, :force, :object, :required, :filename

    # @return [String] datastream name (dsid)
    def datastream_name
      datastream.dsid
    end

    def file_newer_than_datastream?
      filename && (!datastream_date || file_date > datastream_date)
    end

    def file_date
      File.mtime(filename)
    end

    def datastream_date
      datastream.createDate
    end

    def create_from_file(filename)
      content = File.read(filename)
      datastream.content = content
      datastream.ng_xml = Nokogiri::XML(content) if datastream.respond_to?(:ng_xml)
      datastream.save unless datastream.digital_object.new?
    end

    def create_default
      meth = "build_#{datastream_name}_datastream".to_sym
      return unless object.respond_to?(meth)

      object.public_send(meth, datastream)
      datastream.save unless datastream.digital_object.new?
    end

    # Tries to find a file for the datastream.
    # @return [String, nil] path to datastream or nil
    def find_metadata_file
      druid = DruidTools::Druid.new(object.pid, Dor::Config.stacks.local_workspace_root)
      druid.find_metadata("#{datastream_name}.xml")
    end

    def empty_datastream?
      return true if datastream.new?

      return datastream.content.to_s.empty? unless datastream.class.respond_to?(:xml_template)

      datastream.content.to_s.empty? || EquivalentXml.equivalent?(datastream.content, datastream.class.xml_template)
    end
  end
end
