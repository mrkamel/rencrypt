
require File.expand_path("../spec_helper", __dir__)
require "socket"

module Rencrypt
  RSpec.describe HttpSolver do
    describe "#solve" do
      subject do
        described_class.new(
          path: ".well-known/acme-challenge/example_token",
          content_type: "text/plain",
          file_content: "example_token"
        )
      end

      it "serves the http challenge" do
        allow(TCPServer).to receive(:new).and_return(TCPServer.new(8080))
   
        thread = Thread.new { subject.solve }
  
        begin 
          socket = TCPSocket.new("localhost", 8080)
          socket.puts "GET .well-known/acme-challenge/example_token HTTP/1.1"
          socket.puts
     
          expect([socket.gets, socket.gets, socket.gets, socket.gets]).to eq([
            "HTTP/1.1 200 OK\n",
            "Content-Type: text/plain\n",
            "\n",
            "example_token"
          ])
        ensure
          subject.cleanup
        end
      end
    end

    describe "#cleanup" do
      # already tested
    end
  end
end
