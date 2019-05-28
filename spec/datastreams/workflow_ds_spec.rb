# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/EmptyExampleGroup
RSpec.describe Dor::WorkflowDs do
  before { stub_config }

  let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }
end
# rubocop:enable RSpec/EmptyExampleGroup
