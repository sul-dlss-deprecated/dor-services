class Nokogiri::XML::Text
  
  def normalize
    self.content =~ /\S/ ? self.content.gsub(/\s+/,' ').strip : self.content
  end
  
  def normalize!
    self.content = self.normalize
  end

end

class Nokogiri::XML::Node

  def normalize_text!
    self.xpath('//text()').each { |t| t.normalize! }
  end
  
end

class Nokogiri::XML::Document
  
  def prettify
    xslt = Nokogiri::XSLT <<-EOC
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:output omit-xml-declaration="yes" indent="yes"/>
      <xsl:template match="node()|@*">
        <xsl:copy>
          <xsl:apply-templates select="node()|@*"/>
        </xsl:copy>
      </xsl:template>
    </xsl:stylesheet>
    EOC
    xslt.transform(self).to_xml
  end
  
end