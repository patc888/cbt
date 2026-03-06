require 'xcodeproj'

project_path = '/Users/melichan/dev/CBT/CBT.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'CBT' }

seen_sources = {}
target.source_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    ident = build_file.file_ref.uuid
    if seen_sources[ident]
      puts "Removing duplicate source: #{build_file.file_ref.display_name}"
      build_file.remove_from_project
    else
      seen_sources[ident] = true
    end
  end
end

seen_resources = {}
target.resources_build_phase.files.dup.each do |build_file|
  if build_file.file_ref
    ident = build_file.file_ref.uuid
    if seen_resources[ident]
      puts "Removing duplicate resource: #{build_file.file_ref.display_name}"
      build_file.remove_from_project
    else
      seen_resources[ident] = true
    end
  end
end

project.save
