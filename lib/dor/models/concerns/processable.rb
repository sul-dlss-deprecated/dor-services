# frozen_string_literal: true

module Dor
  module Processable
    extend ActiveSupport::Concern

    included do
      has_metadata name: 'workflows',
                   type: Dor::WorkflowDs,
                   label: 'Workflows',
                   control_group: 'E',
                   autocreate: true
    end
  end
end
