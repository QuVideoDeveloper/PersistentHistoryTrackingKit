Pod::Spec.new do |s|
  def self.smart_version
  tag = `git describe --abbrev=0 --tags 2>/dev/null`.strip
  if $?.success? then tag else "0.0.1" end
end
s.name             = 'PersistentHistoryTrackingKit'
s.version          = smart_version
s.summary          = 'A short description of PersistentHistoryTrackingKit.'

s.description      = <<-DESC
TODO: Add long description of the pod here.
DESC

s.homepage         = 'https://github.com/QuVideoDeveloper/PersistentHistoryTrackingKit'
s.license          = { :type => 'MIT', :file => 'LICENSE' }
s.author           = { 'XXY' => 'xinyuan.xu@quvideo.com' }
s.source           = { :git => 'https://github.com/QuVideoDeveloper/PersistentHistoryTrackingKit.git', :tag => s.version.to_s }

s.ios.deployment_target = '16.0'

s.swift_version       = "5.0"
s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

s.source_files = 'Sources/PersistentHistoryTrackingKit/**/*'

end
