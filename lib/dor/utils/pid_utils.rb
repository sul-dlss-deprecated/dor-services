# frozen_string_literal: true

module Dor
  # Utilties for manipulating druids
  class PidUtils
    PID_REGEX = /[a-zA-Z]{2}[0-9]{3}[a-zA-Z]{2}[0-9]{4}/.freeze
    # Since purl does not use the druid: prefix but much of dor does, use this function to strip the druid: if needed
    # @return [String] the druid sans the druid: or if there was no druid: prefix, the entire string you passed
    def self.remove_druid_prefix(druid)
      result = druid.match(PID_REGEX)
      result.nil? ? druid : result[0] # if no matches, return the string passed in, otherwise return the match
    end
  end
end
