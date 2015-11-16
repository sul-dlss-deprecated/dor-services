require 'spec_helper'

describe Dor::DefaultObjectRightsDS do
  before(:each) do
    subject.content = <<XML
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
XML
  end

  it 'understands terms of a rightsMetadata' do
    expect(subject.copyright).to eq(['All rights reserved.'])
    expect(subject.use_statement).to eq(['You may re-distribute this object, unaltered, with attribution to the author.'])
    expect(subject.creative_commons).to eq(['by-nc'])
    expect(subject.creative_commons_human).to eq(['CC Attribution Non-Commercial license'])
    expect(subject.open_data_commons).to eq([])
    expect(subject.open_data_commons_human).to eq([])
  end
  
  it 'understands terms of an empty rightsMetadata' do
    subject.content = '<rightsMetadata/>'
    expect(subject.copyright).to eq([])
    expect(subject.use_statement).to eq([])
    expect(subject.creative_commons).to eq([])
    expect(subject.creative_commons_human).to eq([])
    expect(subject.open_data_commons).to eq([])
    expect(subject.open_data_commons_human).to eq([])
  end
  
  it 'normalizes use element XML' do
    subject.ng_xml.root.add_child('<use><somethingelse>asdf</somethingelse></use>')
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
end
