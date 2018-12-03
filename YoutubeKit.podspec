Pod::Spec.new do |s|
  s.name             = 'YoutubeKit'
  s.version          = '0.3.0+akisute'
  s.summary          = 'YoutubeKit, forked.'

  s.description      = <<-DESC
YoutubeKit, forked. Original: https://github.com/rinov/YoutubeKit
                       DESC

  s.homepage         = 'https://github.com/akisute/YoutubeKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'akisute' => 'akisute+noreply@example.com' }
  s.source           = { :git => 'https://github.com/akisute/YoutubeKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'YoutubeKit/**/*'
  s.resources    = 'YoutubeKit/player.html'

 end
