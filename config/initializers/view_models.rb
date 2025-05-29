# Ensure view_models directory is autoloaded
Rails.application.config.to_prepare do
  Dir.glob(Rails.root.join('app/view_models/**/*.rb')).each do |file|
    require_dependency file
  end
end