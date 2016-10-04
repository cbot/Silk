Pod::Spec.new do |s|
  s.name         = "Silk"
  s.version      = "3.0.0"
  s.summary      = "A thin layer on top of NSURLSession"
  s.homepage     = "https://github.com/cbot/silk"
  s.license      = 'MIT'
  s.author       = { "Kai Straßmann" => "derkai@gmail.com" }
  s.source       = { :git => "https://github.com/cbot/Silk.git", :tag => s.version.to_s }
	s.platforms    = { "ios" => "9.0", "osx" => "10.10"}
  s.requires_arc = true
  s.source_files = 'Classes/*.swift'
  s.frameworks = 'Foundation'
end
