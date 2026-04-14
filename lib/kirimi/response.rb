# frozen_string_literal: true

module Kirimi
  class Response
    attr_reader :success, :data, :message, :raw

    def initialize(hash)
      @raw = hash
      @success = hash['success']
      @data = hash['data']
      @message = hash['message']
    end

    def success?
      @success == true
    end

    def to_s
      "#<Kirimi::Response success=#{@success} message=#{@message.inspect}>"
    end

    def inspect
      to_s
    end
  end
end
