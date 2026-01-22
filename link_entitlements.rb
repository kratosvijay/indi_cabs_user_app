require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
entitlements_path = 'Runner/Runner.entitlements'

project = Xcodeproj::Project.open(project_path)
targets = project.targets.select { |t| t.name == 'Runner' }

# 1. Update Build Settings
targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
    puts "Updated CODE_SIGN_ENTITLEMENTS for target #{target.name} configuration #{config.name}"
  end
end

# 2. Add to Project Group
runner_group = project.main_group.children.find { |c| c.display_name == 'Runner' && c.isa == 'PBXGroup' }

if runner_group
  file_name = 'Runner.entitlements'
  # Check if already exists in group
  file_ref = runner_group.files.find { |f| f.path == file_name }
  
  if file_ref
    puts "Runner.entitlements already exists in project group"
  else
    runner_group.new_file(file_name)
    puts "Added Runner.entitlements to Runner group"
  end
else
  puts "Error: Runner group not found, skipping file addition"
end

project.save
puts "Project saved successfully"
