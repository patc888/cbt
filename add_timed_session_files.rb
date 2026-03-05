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

# Models
add_file(project, target, "#{base_dir}/Models/JournalEntry.swift", 'CBT/Models')

# Services
add_file(project, target, "#{base_dir}/Services/TimedSessionManager.swift", 'CBT/Services')

# Views/TimedSession
add_file(project, target, "#{base_dir}/Views/TimedSession/SessionSummary.swift", 'CBT/Views/TimedSession')
add_file(project, target, "#{base_dir}/Views/TimedSession/TimedSessionSheet.swift", 'CBT/Views/TimedSession')
add_file(project, target, "#{base_dir}/Views/TimedSession/SaveSessionView.swift", 'CBT/Views/TimedSession')
add_file(project, target, "#{base_dir}/Views/TimedSession/JournalEntryDetailView.swift", 'CBT/Views/TimedSession')

project.save
puts "Added timed session files successfully."
