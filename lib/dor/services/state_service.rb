
# frozen_string_literal: true

module Dor
  class StateService
    extend Deprecation

    # having version is preferred as without it, a call to
    # fedora will be made to retrieve it.
    def initialize(pid, version: nil)
      Deprecation.warn(self, 'Dor::StateService is deprecated and will be removed in dor-services 9')
      @pid = pid
      @version = version || fetch_version
    end

    def allows_modification?
      !client.lifecycle('dor', pid, 'submitted') ||
        client.active_lifecycle('dor', pid, 'opened', version: version) ||
        client.workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') == 'hold'
    end

    private

    attr_reader :pid, :version

    def fetch_version
      Deprecation.warn(self, 'Calling the state service without passing in a version is deprecated and will be removed in dor-services 9')
      Dor.find(pid).current_version
    end

    def client
      Dor::Config.workflow.client
    end
  end
end
