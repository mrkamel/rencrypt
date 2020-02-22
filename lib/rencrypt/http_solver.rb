
require "socket"
require "logger"

module Rencrypt
  class HttpSolver
    attr_reader :path, :content_type, :file_content, :logger

    def initialize(path:, content_type:, file_content:, logger: Logger.new("/dev/null"))
      @path = path
      @content_type = content_type
      @file_content = file_content
      @logger = logger
    end

    def solve
      @thread = Thread.new do
        begin
          logger.info "starting server"

          server = TCPServer.new(80)

          loop do
            client = server.accept

            logger.info "new connection"

            line = client.gets.strip

            loop { break if client.gets.strip.empty? }

            if line.include?(path)
              client.puts "HTTP/1.1 200 OK"
              client.puts "Content-Type: #{content_type}"
              client.puts
              client.write file_content
            else
              client.puts "HTTP/1.1 404 Not Found"
              client.puts
            end

            logger.info "response served"

            client.close
          end
        rescue => e
          logger.error(e)
        end
      end 
    end

    def cleanup
      @thread.kill if @thread
    end
  end
end
