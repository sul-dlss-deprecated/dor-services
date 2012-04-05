desc "Bump version number before release"
task :bump_version, [:level] do |t, args|
  levels = ['major','minor','patch','rc']
  version_file = File.expand_path('../../dor/version.rb',__FILE__)
  file_content = File.read(version_file)
  (declaration,version) = file_content.scan(/^(\s*VERSION = )['"](.+)['"]/).flatten
  version = version.split(/\./)
  index = levels.index(args[:level] || (version.length == 4 ? 'rc' : 'patch'))
  if version.length == 4 and index < 3
    version.pop
  end
  if index == 3
    puts version.inspect
    rc = version.length == 4 ? version.pop : 'rc0'
    puts rc
    rc.sub!(/^rc(\d+)$/) { |m| "rc#{$1.to_i+1}" }
    puts rc
    version << rc
    puts version.inspect
  else
    version[index] = version[index].to_i+1
    (index+1).upto(2) { |i| version[i] = '0' }
  end
  version = version.join('.')
  file_content.sub!(/^(\s*VERSION = )['"](.+)['"]/,"#{declaration}'#{version}'")
  File.open(version_file,'w') { |f| f.write(file_content) }
  
  readme_file = File.expand_path('../../../README.rdoc',__FILE__)
  file_content = File.read(readme_file)
  lines = file_content.lines.to_a
  line = lines.index(lines.find { |l| l =~ /^== Copyright/ })
  lines.insert(line-1, "- <b>#{version}</b>\n")
  File.open(readme_file,'w') { |f| f.write(lines.join("")) }
  if File.basename(ENV['EDITOR']) =~ /^r?mate$/
    `#{ENV['EDITOR']} -l #{line} -w #{readme_file}`
  end

  $stderr.puts "Version bumped to #{version}"
end
