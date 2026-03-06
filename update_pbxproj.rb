require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

def add_file(project, target, file_path, group_path)
  group = project.main_group
  group_path.split('/').each do |g|
    group = group.groups.find { |x| x.name == g || x.path == g } || group.new_group(g)
  end
  
  file_ref = group.files.find { |f| f.path == File.basename(file_path) }
  unless file_ref
    file_ref = group.new_reference(file_path)
  end
  
  unless target.source_build_phase.files.find { |f| f.file_ref == file_ref }
    target.source_build_phase.add_file_reference(file_ref)
  end
end

def remove_file(project, target, file_path)
  file_name = File.basename(file_path)
  
  target.source_build_phase.files.dup.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == file_name
      build_file.remove_from_project
    end
  end
  
  def remove_from_group(group, file_name)
    group.children.dup.each do |child|
      if child.class == Xcodeproj::Project::Object::PBXFileReference && child.path == file_name
        child.remove_from_project
      elsif child.class == Xcodeproj::Project::Object::PBXGroup
        remove_from_group(child, file_name)
      end
    end
  end
  
  remove_from_group(project.main_group, file_name)
end

base_dir = '/Users/melichan/dev/CBT/CBT'

add_file(project, target, "#{base_dir}/Views/Journal/JournalView.swift", 'CBT/Views/Journal')
add_file(project, target, "#{base_dir}/Views/Journal/JournalSessionsListView.swift", 'CBT/Views/Journal')
add_file(project, target, "#{base_dir}/Views/Journal/JournalSessionRow.swift", 'CBT/Views/Journal')

remove_file(project, target, "#{base_dir}/Views/Placeholders.swift")

project.save
puts "Successfully updated project"
