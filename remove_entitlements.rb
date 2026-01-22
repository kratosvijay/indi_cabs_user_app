require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'

project = Xcodeproj::Project.open(project_path)
targets = project.targets.select { |t| t.name == 'Runner' }

# 1. Remove Build Settings
targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
    puts "Removed CODE_SIGN_ENTITLEMENTS from target #{target.name} configuration #{config.name}"
  end
end

# 2. Remove from Project Group
runner_group = project.main_group.children.find { |c| c.display_name == 'Runner' && c.isa == 'PBXGroup' }

if runner_group
  file_name = 'Runner.entitlements'
  file_ref = runner_group.files.find { |f| f.path == file_name }
  if file_ref
    file_ref.remove_from_project
    puts "Removed Runner.entitlements from project group"
  end
end

project.save
puts "Project saved successfully"
