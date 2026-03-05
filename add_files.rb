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
  unless target.source_build_phase.files.find { |f| f.file_ref == file_ref } || target.resources_build_phase.files.find { |f| f.file_ref == file_ref }
    if file_path.end_with?('.json')
      target.resources_build_phase.add_file_reference(file_ref)
    else
      target.source_build_phase.add_file_reference(file_ref)
    end
  end
end

base_dir = '/Users/melichan/dev/CBT/CBT'

# Add Resources/Exercises.json
add_file(project, target, "#{base_dir}/Resources/Exercises.json", 'CBT/Resources')

# Add Models/Exercise.swift
add_file(project, target, "#{base_dir}/Models/Exercise.swift", 'CBT/Models')

# Add Services/ExerciseLoader.swift
add_file(project, target, "#{base_dir}/Services/ExerciseLoader.swift", 'CBT/Services')

# Add Views/Exercises/ExercisesView.swift
add_file(project, target, "#{base_dir}/Views/Exercises/ExercisesView.swift", 'CBT/Views/Exercises')

# Add Views/Exercises/ExerciseCategoryView.swift
add_file(project, target, "#{base_dir}/Views/Exercises/ExerciseCategoryView.swift", 'CBT/Views/Exercises')

# Add Views/Exercises/ExerciseDetailView.swift
add_file(project, target, "#{base_dir}/Views/Exercises/ExerciseDetailView.swift", 'CBT/Views/Exercises')

project.save
puts "Added files successfully."
