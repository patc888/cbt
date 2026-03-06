require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

seen = {}
target.source_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    path = build_file.file_ref.path
    if seen[path]
      puts "Removing duplicate: #{path}"
      build_file.remove_from_project
    else
      seen[path] = true
    end
  end
end

project.save
