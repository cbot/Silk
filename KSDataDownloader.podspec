Pod::Spec.new do |s|
  s.name         = "KSDataDownloader"
  s.version      = "1.0.4"
  s.summary      = "A thin layer on top of NSURLConnection"
  s.homepage     = "https://github.com/cbot/KSDataDownloader"
  s.license      = 'MIT'
  s.author       = { "Kai Straßmann" => "derkai@gmail.com" }
  s.source       = { :git => "https://github.com/cbot/KSDataDownloader.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.requires_arc = true
  s.public_header_files = 'Classes/ios/*.h'
  s.source_files = 'Classes/ios/*'
  s.frameworks = 'Foundation', 'UIKit'
end
