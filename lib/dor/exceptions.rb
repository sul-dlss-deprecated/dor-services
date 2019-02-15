# frozen_string_literal: true

module Dor
  class Exception < ::StandardError; end
  class ParameterError < RuntimeError; end

  # Raised when the data does not conform to expectations
  class DataError < RuntimeError; end

  # Raised when trying to open a version that is already open
  # rubocop:disable Lint/InheritException
  # See https://github.com/rubocop-hq/rubocop/issues/6770
  class VersionAlreadyOpenError < Exception; end
  # rubocop:enable Lint/InheritException

  class DuplicateIdError < RuntimeError
    attr_reader :pid

    def initialize(pid)
      @pid = pid
    end
  end
end
