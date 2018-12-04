# frozen_string_literal: true

module Dor
  # Merges contentMetadata from several objects into one.
  class SecondaryFileNameService
    def self.create(old_name, sequence_num)
      old_name =~ /^(.*)\.(.*)$/ ? "#{Regexp.last_match(1)}_#{sequence_num}.#{Regexp.last_match(2)}" : "#{old_name}_#{sequence_num}"
    end
  end
end
