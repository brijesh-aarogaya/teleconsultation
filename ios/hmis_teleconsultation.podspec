Pod::Spec.new do |s|
  s.name             = 'hmis_teleconsultation'
  s.version          = '0.0.1'
  s.summary          = 'HMIS Teleconsultation Flutter Plugin'
  s.description      = <<-DESC
A separate, modular Flutter package for Agora RTC-based Teleconsultation in HMIS.
                       DESC
  s.homepage         = 'https://aarogyaone.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AarogyaOne' => 'support@aarogyaone.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
