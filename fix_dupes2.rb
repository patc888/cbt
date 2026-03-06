require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

seen_sources = {}
target.source_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    path = build_file.file_ref.real_path.to_s
    if seen_sources[path]
      puts "Removing duplicate source: #{path}"
      build_file.remove_from_project
    else
      seen_sources[path] = true
    end
  end
end

seen_resources = {}
target.resources_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    path = build_file.file_ref.real_path.to_s
    if seen_resources[path]
      puts "Removing duplicate resource: #{path}"
      build_file.remove_from_project
    else
      seen_resources[path] = true
    end
  end
end

project.save
