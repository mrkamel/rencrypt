
require File.expand_path("../spec_helper", __dir__)

module Rencrypt
  RSpec.describe FloatingIp do
    describe "#server_name" do
      let(:http_auth) { instance_double(HTTP::Client) }
      let(:floating_ips_response) { instance_double(HTTP::Response) }
      let(:server_response) { instance_double(HTTP::Response) }

      before do
        allow(HTTP).to receive(:auth).and_return(http_auth)
        allow(http_auth).to receive(:get).with("https://api.hetzner.cloud/v1/floating_ips").and_return(floating_ips_response)
        allow(http_auth).to receive(:get).with("https://api.hetzner.cloud/v1/servers/1").and_return(server_response)

        allow(floating_ips_response).to receive(:parse).and_return({
          "floating_ips" => [
            { "ip" => "1.1.1.1", "server" => 1 },
            { "ip" => "2.2.2.2", "server" => 2 }
          ]
        })

        allow(server_response).to receive(:parse).and_return(
          { "server" => { "name" => "server.tld" } }
        )
      end

      it "returns the server name if the ip is known" do
        expect(described_class.new(token: "token", ip: "1.1.1.1").server_name).to eq("server.tld")
      end

      it "raises IpNotFoundError if the ip is unknown" do
        expect { described_class.new(token: "token", ip: "3.3.3.3").server_name }.to raise_error(described_class::IpNotFoundError)
      end
    end
  end
end
