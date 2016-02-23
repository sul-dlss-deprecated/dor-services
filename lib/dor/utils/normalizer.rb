module Dor
  module Utils
    # This class provides methods to normalize MODS XML according to the Stanford guidelines.
    # @see https://consul.stanford.edu/display/chimera/MODS+validation+and+normalization Requirements (Stanford Consul page - requires login)
    class Normalizer
      # Linefeed character entity reference
      LINEFEED = '&#10;'

      # Recursive helper method for {Normalizer#clean_linefeeds} to do string substitution.
      #
      # @param [Nokogiri::XML::Element]   node   An XML node
      # @return [String]                  A string composed of the entire contents of the given node, with substitutions made as described for {#clean_linefeeds}.
      def substitute_linefeeds(node)
        new_text = String.new

        # If we substitute in '&#10;' by itself, Nokogiri interprets that and then prints '&amp;#10;' when printing the document later. This
        # is an ugly way to add linefeed characters in a way that we at least get well-formatted output in the end.
        if(node.text?)
          new_text = node.content.gsub(/\r\n/, Nokogiri::HTML(LINEFEED).text).gsub(/\n/, Nokogiri::HTML(LINEFEED).text).gsub(/\r/, Nokogiri::HTML(LINEFEED).text).gsub('\\n', Nokogiri::HTML(LINEFEED).text)
        else
          if(node.node_name == 'br')
            new_text += Nokogiri::HTML(LINEFEED).text
          elsif(node.node_name == 'p')
            new_text += Nokogiri::HTML(LINEFEED).text + Nokogiri::HTML(LINEFEED).text
          end

          node.children.each do |c|
            new_text += substitute_linefeeds(c)
          end
        end
        return new_text
      end


      # Given a list of Nokogiri elements from XML document, replaces linefeed characters with &#10;
      # \n, \r, <br> and <br/> are all replaced by a single &#10;
      # <p> is replaced by two &#10;
      # </p> is removed
      # \r\n is replaced by &#10;
      # Any tags not listed above are removed.
      #
      # @param   [Nokogiri::XML::NodeSet]    node_list
      # @return  [Void]                      This method doesn't return anything, but introduces UTF-8 linefeed characters in place, as described above.
      def clean_linefeeds(node_list)
        node_list.each do |current_node|
          new_text = substitute_linefeeds(current_node)
          current_node.children.remove
          current_node.content = new_text
        end
      end

      # Removes empty attributes from a given node.
      #
      # @param [Nokogiri::XML::Element]   node An XML node.
      # @return [Void]                    This method doesn't return anything, but modifies the XML tree starting at the given node.
      def remove_empty_attributes(node)
        children = node.children
        attributes = node.attributes

        attributes.each do |key, value|
          node.remove_attribute(key) if(value.to_s.strip.empty?)
        end

        children.each do |c|
          remove_empty_attributes(c)
        end
      end


      # Removes empty nodes from an XML tree.
      #
      # @param  [Nokogiri::XML::Element]   node An XML node.
      # @return [Void]                     This method doesn't return anything, but modifies the XML tree starting at the given node.
      def remove_empty_nodes(node)
        children = node.children

        if(node.text?)
          if(node.to_s.strip.empty?)
            node.remove
          else
            return
          end
        elsif(children.length > 0)
          children.each do |c|
            remove_empty_nodes(c)
          end
        end

        if(node.children.length == 0)
          node.remove
        end
      end


      # Removes leading and trailing spaces from a node.
      #
      # @param  [Nokogiri::XML::Element]  node An XML node.
      # @return [Void]                    This method doesn't return anything, but modifies the entire XML tree starting at the
      #                                   the given node, removing leading and trailing spaces from all text. If the input is nil,
      #                                   an exception will be raised.
      def trim_text(node)
        children = node.children

        if(node.text?)
          node.parent.content = node.text.strip
        else
          children.each do |c|
            trim_text(c)
          end
        end
      end

      # Normalizes the given XML document string according to the Stanford guidelines.
      #
      # @param  [String]   xml_string    An XML document
      # @return [String]                 The XML string, with normalizations applied.
      def normalize_xml_string(xml_string)
        doc = Nokogiri::XML(xml_string)
        normalize_document(doc.root)
        doc.to_s
      end
    end
  end
end