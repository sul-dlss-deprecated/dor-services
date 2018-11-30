# frozen_string_literal: true

module Dor
  class Exception < ::StandardError; end
  class ParameterError < RuntimeError; end
  class DuplicateIdError < RuntimeError
    attr_reader :pid

    def initialize(pid)
      @pid = pid
    end
  end
end
