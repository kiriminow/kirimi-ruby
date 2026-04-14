# frozen_string_literal: true

module Kirimi
  class Error < StandardError; end

  class ApiError < Error
    attr_reader :status_code, :response_data

    def initialize(status_code, message, response_data = nil)
      super(message)
      @status_code = status_code
      @response_data = response_data
    end
  end

  class NetworkError < Error; end
end
