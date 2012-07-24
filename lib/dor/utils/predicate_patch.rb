# Monkey patch ActiveFedora::RelsExtDatastream.short_predicate to
# create missing mappings on the fly.

module ActiveFedora
  class RelsExtDatastream
    def self.short_predicate(predicate)
      # for this regex to short-circuit correctly, namespaces must be sorted into descending order by length
      if match = /^(#{Predicates.predicate_mappings.keys.sort.reverse.join('|')})(.+)$/.match(predicate.to_str)
        namespace = match[1]
        predicate = match[2]
        ns_mapping = Predicates.predicate_mappings[namespace] ||= {}
        pred = ns_mapping.invert[predicate]
        if pred.nil?
          pred = predicate.underscore.to_sym
          ns_mapping[pred] = predicate
        end
        pred
      else
        raise "Unable to parse predicate: #{predicate}"
      end
    end
  end
end