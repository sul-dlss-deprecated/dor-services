# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::AdminPolicyObject do
  describe 'datastreams' do
    subject { described_class.ds_specs.keys }
    it do
      is_expected.to eq ['RELS-EXT', 'DC', 'identityMetadata',
                         'events', 'rightsMetadata', 'descMetadata', 'versionMetadata',
                         'workflows', 'administrativeMetadata', 'roleMetadata',
                         'defaultObjectRights']
    end
  end
end
