
require File.expand_path("../spec_helper", __dir__)
require "fileutils"

RSpec.describe Rencrypt::Certificate do
  let(:base_path) { "/tmp/letsencrypt" }
  let(:common_name) { "example.com" }
  let(:before_script) {}
  let(:after_script) {}

  let(:certificate_path) { File.join(base_path, common_name, "crt.pem") }
  let(:private_key_path) { File.join(base_path, common_name, "key.pem") }
  let(:full_path) { File.join(base_path, common_name, "full.pem") }

  subject do
    described_class.new(
      base_path: base_path,
      common_name: common_name,
      email: "email@example.com",
      before_script: before_script,
      after_script: after_script
    )
  end

  before { FileUtils.mkdir_p(File.join(base_path, common_name)) }
  after { FileUtils.rm_rf(File.join(base_path, common_name)) }

  describe "#update" do
    let(:acme_client) { instance_double(Acme::Client) }
    let(:order) { instance_double(Acme::Client::Resources::Order) }
    let(:authorization) { instance_double(Acme::Client::Resources::Authorization) }
    let(:http_challenge) { instance_double(Acme::Client::Resources::Challenges::HTTP01) }

    before do
      allow(Acme::Client).to receive(:new).and_return(acme_client)

      allow(acme_client).to receive(:new_order).and_return(order)
      allow(acme_client).to receive(:new_account)

      allow(order).to receive(:authorizations).and_return([authorization])
      allow(order).to receive(:finalize)
      allow(order).to receive(:status).and_return("processed")
      allow(order).to receive(:certificate).and_return("certificate")

      allow(authorization).to receive(:http).and_return(http_challenge)

      allow(http_challenge).to receive(:request_validation)
      allow(http_challenge).to receive(:filename).and_return("filename")
      allow(http_challenge).to receive(:content_type).and_return("text/plain")
      allow(http_challenge).to receive(:file_content).and_return("file content")
      allow(http_challenge).to receive(:status).and_return("valid")
      allow(http_challenge).to receive(:reload)
    end

    context "with scripts" do
      let(:before_script) { "touch /tmp/before_script" }
      let(:after_script) { "touch /tmp/after_script" }

      after do
        FileUtils.rm_f "/tmp/before_script"
        FileUtils.rm_f "/tmp/after_script"
      end

      it "runs the before script" do
        subject.update

        expect(File.exists?("/tmp/before_script")).to eq(true)
      end

      it "runs the after script" do
        subject.update

        expect(File.exists?("/tmp/after_script")).to eq(true)
      end
    end

    it "requests the http challenge" do
      subject.update

      expect(http_challenge).to have_received(:request_validation)
    end

    it "answers the http challenge" do
      allow(http_challenge).to receive(:status).and_return("pending")
      allow(TCPServer).to receive(:new).and_return(TCPServer.new(8080))

      thread = Thread.new { subject.update }

      sleep 0.5

      socket = TCPSocket.new("localhost", 8080)
      socket.puts "GET filename HTTP/1.1"
      socket.puts

      expect([socket.gets, socket.gets, socket.gets, socket.gets].map(&:strip)).to eq([
        "HTTP/1.1 200 OK",
        "Content-Type: text/plain",
        "",
        "file content"
      ])

      allow(http_challenge).to receive(:status).and_return("valid")

      thread.join
    end

    it "obtains and writes the certificate" do
      subject.update

      expect(File.read(certificate_path)).to eq("certificate")
    end
  end

  describe "#exists?" do
    it "returns true if the certificate file exists" do
      FileUtils.touch(certificate_path)

      expect(subject.exists?).to eq(true)
    end

    it "returns false if the certificate file does not exist" do
      expect(subject.exists?).to eq(false)
    end
  end

  describe "#write" do
    before { subject.write(private_key: "private key", certificate: "certificate") }

    it "writes the private key" do
      expect(File.read(private_key_path)).to eq("private key")
    end

    it "writes the certificate" do
      expect(File.read(certificate_path)).to eq("certificate")
    end

    it "writes the full file" do
      expect(File.read(full_path)).to eq("certificate\nprivate key")
    end
  end

  describe "#not_after" do
    it "returns the expiration date of the certificate" do
      certificate_content =<<~CERTIFICATE
        -----BEGIN CERTIFICATE-----
        MIIC/zCCAeegAwIBAgIJANmlPMlm7YUcMA0GCSqGSIb3DQEBBQUAMBYxFDASBgNV
        BAMMC2V4YW1wbGUuY29tMB4XDTIwMDIyMDIyMjYyNloXDTMwMDIxNzIyMjYyNlow
        FjEUMBIGA1UEAwwLZXhhbXBsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
        ggEKAoIBAQCb19BlQF2O8kL3KLJtfe0gjQnU66n2DoCQTNF6ScV89yeGTvmrB+pa
        lRCNAe+cZU0vu9O7GSrxp3Ci7T9n2pvFNNP6YyzV8QgY62Tu/S3MRTkK8915RLqr
        f2awax1wZ4MGibYnYklcYKf5x6X6Okdxodlg8Ab7hm+KB2/E8TXaNw3FhT4oBWUN
        A+Em3QlGF1W31lALWMyRkrr2IB2IEGPtLqwFJsfgJR0WdTD7hzckCXnNgVPPEATt
        UuaJ6hqRSSydx+OlUkwoATpmwv1E/yE6Nl/yTGFuFQMWatlaE88EHA+p8EIiq9wz
        2Je8kvq2j4ssL8HZy28BWj9aHJw6mx33AgMBAAGjUDBOMB0GA1UdDgQWBBRx9qho
        yrixlB1GEEOhjHL2wbbzzDAfBgNVHSMEGDAWgBRx9qhoyrixlB1GEEOhjHL2wbbz
        zDAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQCL3uOkAOqEWRYJxOHl
        loix+plwXtFsBZJCeSd10sK5+He4OJz+h6Z/CJRHtYHqsd6WzobkxMSeXwVCFPGt
        R6OM2i0tdYzF/PDvCtGjLMPT+sNouVkES0GYt8KfoZR7zQIa8q9B3dgNrkopG2Jm
        1vef4dZt1vAnsSiHkYU3Oa79A5TTqCmz6K4gq+nQ9btgr+W0QH8dDdnIH+OHFq30
        pXto+pZkhdA2DAZGQMKLZ3rUwXNqrRTdPeyFM3Xi4q1frkdOR+sbiBaktacs07zI
        UBsKf3kBbdPnaMUaDifebAd5Ewal1yCdK9arjbV4I94CpIJC3Q71tsYnnJZ/gVKH
        alPd
        -----END CERTIFICATE-----
      CERTIFICATE

      File.write(certificate_path, certificate_content)

      expect(subject.not_after).to eq(Time.parse("2030-02-17 22:26:26 UTC"))
    end
  end

  describe "#read_private_key" do
    it "returns the private key" do
      File.write(private_key_path, "private key")

      expect(subject.read_private_key).to eq("private key")
    end
  end

  describe "#read_certificate" do
    it "returns the certificate" do
      File.write(certificate_path, "certificate")

      expect(subject.read_certificate).to eq("certificate")
    end
  end
end
