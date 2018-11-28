# frozen_string_literal: true

require 'spec_helper'

describe Dor::DefaultObjectRightsDS do
  before(:each) do
    subject.content = <<~XML
      <rightsMetadata objectId="druid">
         <copyright>
            <human type="copyright">  All rights reserved.  </human>
         </copyright>
         <access type="discover"><machine><world/></machine></access>
         <access type="read">
            <machine><world/></machine>
         </access>
         <use>
            <human type="useAndReproduction">  You may re-distribute this object, unaltered, with attribution to the author.  </human>
         </use>
         <use>
            <human type="creativeCommons">
              CC Attribution Non-Commercial license
            </human>
            <machine type="creativeCommons" uri="https://creativecommons.org/licenses/by-nc/3.0/">
              by-nc
            </machine>
         </use>

      </rightsMetadata>
XML
  end

  it 'understands terms of a rightsMetadata and will normalize the text' do
    subject.normalize!
    expect(subject.copyright).to eq(['All rights reserved.'])
    expect(subject.use_statement).to eq(['You may re-distribute this object, unaltered, with attribution to the author.'])
    expect(subject.creative_commons).to eq(['by-nc'])
    expect(subject.creative_commons_human).to eq(['CC Attribution Non-Commercial license'])
    expect(subject.open_data_commons).to eq([])
    expect(subject.open_data_commons_human).to eq([])
    expect(subject.ng_xml.at_xpath('/rightsMetadata/access[@type="discover"]/machine/world')).to be_a(Nokogiri::XML::Node)
    expect(subject.ng_xml.at_xpath('/rightsMetadata/access[@type="read"]/machine/world')).to be_a(Nokogiri::XML::Node)
  end

  it 'understands terms of an empty rightsMetadata' do
    subject.content = '<rightsMetadata/>'
    subject.normalize!
    expect(subject.copyright).to eq([])
    expect(subject.use_statement).to eq([])
    expect(subject.creative_commons).to eq([])
    expect(subject.creative_commons_human).to eq([])
    expect(subject.open_data_commons).to eq([])
    expect(subject.open_data_commons_human).to eq([])
  end

  it 'normalizes use element XML' do
    expect(subject.ng_xml.xpath('/rightsMetadata/use').length).to eq(2)
    subject.normalize!
    expect(subject.ng_xml.xpath('/rightsMetadata/use').length).to eq(1)
  end

  it 'normalizes copyright XML' do
    subject.normalize!
    expect(subject.ng_xml.xpath('/rightsMetadata/copyright').length).to eq(1)
    subject.ng_xml.root.at_xpath('/rightsMetadata/copyright').remove
    subject.ng_xml.root.add_child('<copyright/>')
    subject.normalize!
    expect(subject.ng_xml.xpath('/rightsMetadata/copyright').length).to eq(0)
  end

  it 'normalizes use statement XML' do
    subject.normalize!
    expect(subject.ng_xml.xpath('/rightsMetadata/use/human[@type=\'useAndReproduction\']').length).to eq(1)
    subject.ng_xml.at_xpath('/rightsMetadata/use/human[@type=\'useAndReproduction\']/text()').remove
    expect(subject.use_statement).to eq([''])
    expect(subject.ng_xml.xpath('/rightsMetadata/use/human[@type=\'useAndReproduction\']').length).to eq(1)
    subject.normalize!
    expect(subject.ng_xml.xpath('/rightsMetadata/use/human[@type=\'useAndReproduction\']').length).to eq(0)
  end

  it 'is human-readable XML' do
    subject.normalize!
    expect(subject.content).to eq('<?xml version="1.0" encoding="UTF-8"?>

<rightsMetadata objectId="druid">
   <copyright>
      <human type="copyright">All rights reserved.</human>
   </copyright>
   <access type="discover">
      <machine>
         <world/>
      </machine>
   </access>
   <access type="read">
      <machine>
         <world/>
      </machine>
   </access>
   <use>
      <human type="useAndReproduction">You may re-distribute this object, unaltered, with attribution to the author.</human>
      <human type="creativeCommons">CC Attribution Non-Commercial license</human>
      <machine type="creativeCommons" uri="https://creativecommons.org/licenses/by-nc/3.0/">by-nc</machine>
   </use>
</rightsMetadata>
')
  end

  describe 'prettify' do
    it 'correctly indents XML' do
      expected_result = '<?xml version="1.0" encoding="UTF-8"?>

<rightsMetadata objectId="druid">
   <copyright>
      <human type="copyright">  All rights reserved.  </human>
   </copyright>
   <access type="discover">
      <machine>
         <world/>
      </machine>
   </access>
   <access type="read">
      <machine>
         <world/>
      </machine>
   </access>
   <use>
      <human type="useAndReproduction">  You may re-distribute this object, unaltered, with attribution to the author.  </human>
   </use>
   <use>
      <human type="creativeCommons">
        CC Attribution Non-Commercial license
      </human>
      <machine type="creativeCommons" uri="https://creativecommons.org/licenses/by-nc/3.0/">
        by-nc
      </machine>
   </use>
</rightsMetadata>
'
      default_object_rights = Dor::DefaultObjectRightsDS.new
      pretty_xml = default_object_rights.prettify(Nokogiri::XML(subject.content))
      expect(pretty_xml).to eq(expected_result)
    end
  end
end
