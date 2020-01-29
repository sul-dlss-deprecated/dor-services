# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Collection do
  describe '.datastreams' do
    subject { described_class.ds_specs.keys }

    it do
      expect(subject).to match_array %w[RELS-EXT DC identityMetadata
                                        events rightsMetadata descMetadata versionMetadata
                                        provenanceMetadata]
    end
  end
end
