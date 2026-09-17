# frozen_string_literal: true

# RSpec + WebMock suite. Requires Ruby >= 3.0 and the dev gems declared in
# kirimi.gemspec (rspec, webmock).
#
#   bundle install
#   bundle exec rspec        # or: bundle exec rake

require 'kirimi'
require 'tempfile'
require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  WebMock.disable_net_connect!
end
