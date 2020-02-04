# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::StaticConfig do
  let(:defaults) { YAML.safe_load(File.read(File.expand_path('../config/config_defaults.yml', __dir__))).deep_symbolize_keys }
  let(:config) do
    described_class.new(defaults)
  end

  describe 'nested config' do
    before do
      config.configure do
        fedora do
          url 'my-fedora'
        end

        solr do
          url 'my-solr'
        end

        stacks do
          document_cache_host 'purl-test'
        end
      end
    end

    it 'configures the items' do
      expect(config.fedora.url).to eq 'my-fedora'
      expect(config.solr.url).to eq 'my-solr'
      expect(config.stacks.document_cache_host).to eq 'purl-test'
    end
  end
end
