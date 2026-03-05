require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

def add_file(project, target, file_path, group_path)
  group = project.main_group
  group_path.split('/').each do |g|
    group = group.groups.find { |x| x.name == g || x.path == g } || group.new_group(g)
  end
  
  # Check if file already in group
  file_ref = group.files.find { |f| f.path == File.basename(file_path) }
  unless file_ref
    file_ref = group.new_reference(file_path)
  end
  
  # Check if already in build phases
  unless target.source_build_phase.files.find { |f| f.file_ref == file_ref }
    target.source_build_phase.add_file_reference(file_ref)
  end
end

base_dir = '/Users/melichan/dev/CBT/CBT'

add_file(project, target, "#{base_dir}/Utilities/Color+Extensions.swift", 'CBT/Utilities')
add_file(project, target, "#{base_dir}/Utilities/AppTheme.swift", 'CBT/Utilities')
add_file(project, target, "#{base_dir}/Utilities/ThemeManager.swift", 'CBT/Utilities')
add_file(project, target, "#{base_dir}/Components/ThemeBackgrounds.swift", 'CBT/Components')

project.save
puts "Added files successfully."
