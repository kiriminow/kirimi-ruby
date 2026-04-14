# frozen_string_literal: true

# NOTE: RSpec + WebMock tests require Ruby >= 3.0 and the following gems:
#   gem 'rspec',   '~> 3.12'
#   gem 'webmock', '~> 3.19'
#
# For Ruby 2.6 compatibility, use the Minitest suite in test/ instead:
#   ruby -Ilib:test test/client_test.rb

require 'kirimi'
require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  WebMock.disable_net_connect!
end
