# frozen_string_literal: true

require_relative 'lib/kirimi/version'

Gem::Specification.new do |spec|
  spec.name    = 'kirimi'
  spec.version = Kirimi::VERSION
  spec.authors = ['Kirimi']
  spec.email   = ['support@kirimi.id']

  spec.summary     = 'Official Ruby SDK for Kirimi WhatsApp API'
  spec.description = 'Send WhatsApp messages, OTP, broadcasts, and more via the Kirimi API.'
  spec.homepage    = 'https://github.com/kiriminow/kirimi-ruby'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files         = Dir.glob(%w[lib/**/* LICENSE README.md CHANGELOG.md kirimi.gemspec])
  spec.test_files    = Dir.glob('test/**/*_test.rb')
  spec.require_paths = ['lib']

  # No runtime dependencies — uses only Ruby stdlib (net/http, json, securerandom)

  spec.add_development_dependency 'rake', '~> 13.0'
end
