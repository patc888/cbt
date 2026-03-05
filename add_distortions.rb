require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

def add_file(project, target, file_path, group_path)
  group = project.main_group
  
  # Traverse and create groups if needed
  group_path.split('/').reject(&:empty?).each do |g|
    existing_group = group.groups.find { |x| x.name == g || x.path == g }
    group = existing_group || group.new_group(g, g)
  end
  
  # Check if file already in group
  file_ref = group.files.find { |f| f.path == File.basename(file_path) || f.path == file_path }
  unless file_ref
    file_ref = group.new_reference(file_path)
  end
  
  # Check if already in build phases
  in_source = target.source_build_phase.files.find { |f| f.file_ref == file_ref }
  in_resources = target.resources_build_phase.files.find { |f| f.file_ref == file_ref }
  
  unless in_source || in_resources
    if file_path.end_with?('.json')
      target.resources_build_phase.add_file_reference(file_ref)
    else
      target.source_build_phase.add_file_reference(file_ref)
    end
  end
end

base_dir = '/Users/melichan/dev/CBT/CBT'

add_file(project, target, "#{base_dir}/Resources/CognitiveDistortions.json", 'CBT/Resources')
add_file(project, target, "#{base_dir}/Models/CognitiveDistortionExample.swift", 'CBT/Models')
add_file(project, target, "#{base_dir}/Services/CognitiveDistortionsLibrary.swift", 'CBT/Services')
add_file(project, target, "#{base_dir}/Views/Exercises/Distortions/DistortionExamplesView.swift", 'CBT/Views/Exercises/Distortions')
add_file(project, target, "#{base_dir}/Views/Exercises/Distortions/DistortionExampleCardView.swift", 'CBT/Views/Exercises/Distortions')

project.save
puts "Added new files successfully."
