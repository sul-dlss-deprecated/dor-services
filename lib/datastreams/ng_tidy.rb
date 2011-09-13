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
