# frozen_string_literal: true

require 'spec_helper'

describe Dor::RoleMetadataDS do
  context '#to_solr' do
    it 'creates solr docs from its content' do
      xml = <<-XML
      <roleMetadata>
        <role type="dor-apo-manager">
          <group>
            <identifier type="workgroup">dlss:dor-admin</identifier>
          </group>
        </role>
      </roleMetadata>
      XML
      ds = Dor::RoleMetadataDS.from_xml xml
      doc = ds.to_solr

      expect(doc['apo_register_permissions_ssim']).to include('workgroup:dlss:dor-admin')
      expect(doc['apo_register_permissions_tesim']).to include('workgroup:dlss:dor-admin')
    end

    it 'does not index apo_register_permissions from hydrus roles' do
      xml = <<-XML
      <roleMetadata>
        <role type="hydrus-user">
          <group>
            <identifier type="workgroup">dlss:dor-admin</identifier>
          </group>
        </role>
      </roleMetadata>
      XML
      ds = Dor::RoleMetadataDS.from_xml xml
      doc = ds.to_solr

      expect(doc).to_not have_key('apo_register_permissions_ssim')
      expect(doc).to_not have_key('apo_register_permissions_tesim')
    end
  end
end
