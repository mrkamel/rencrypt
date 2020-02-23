
require File.expand_path("../spec_helper", __dir__)
require "fileutils"

module Rencrypt
  RSpec.describe Certificate do
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

    let(:acme_client) { instance_double(Acme::Client) }
    let(:order) { instance_double(Acme::Client::Resources::Order) }
    let(:authorization) { instance_double(Acme::Client::Resources::Authorization) }
    let(:http_challenge) { instance_double(Acme::Client::Resources::Challenges::HTTP01) }
    let(:dns_challenge) { instance_double(Acme::Client::Resources::Challenges::DNS01) }
    let(:http_solver) { instance_double(HttpSolver) }
    let(:dns_solver) { instance_double(DnsSolver) }

    before do
      allow(Acme::Client).to receive(:new).and_return(acme_client)

      allow(acme_client).to receive(:new_order).and_return(order)
      allow(acme_client).to receive(:new_account)

      allow(order).to receive(:authorizations).and_return([authorization])
      allow(order).to receive(:finalize)
      allow(order).to receive(:status).and_return("processed")
      allow(order).to receive(:certificate).and_return("certificate")

      allow(authorization).to receive(:http).and_return(http_challenge)
      allow(authorization).to receive(:dns).and_return(dns_challenge)

      allow(http_challenge).to receive(:request_validation)
      allow(http_challenge).to receive(:filename).and_return("filename")
      allow(http_challenge).to receive(:content_type).and_return("text/plain")
      allow(http_challenge).to receive(:file_content).and_return("file content")
      allow(http_challenge).to receive(:status).and_return("valid")
      allow(http_challenge).to receive(:reload)

      allow(dns_challenge).to receive(:request_validation)
      allow(dns_challenge).to receive(:record_name).and_return("record.name")
      allow(dns_challenge).to receive(:record_type).and_return("TXT")
      allow(dns_challenge).to receive(:record_content).and_return("record content")
      allow(dns_challenge).to receive(:status).and_return("valid")
      allow(dns_challenge).to receive(:reload)

      allow(HttpSolver).to receive(:new).and_return(http_solver)
      allow(http_solver).to receive(:solve)
      allow(http_solver).to receive(:cleanup)

      allow(DnsSolver).to receive(:new).and_return(dns_solver)
      allow(dns_solver).to receive(:solve)
      allow(dns_solver).to receive(:cleanup)
    end

    describe "#update_http" do
      let(:call) { subject.update_http }

      context "with scripts" do
        let(:before_script) { "touch /tmp/before_script" }
        let(:after_script) { "touch /tmp/after_script" }

        after do
          FileUtils.rm_f "/tmp/before_script"
          FileUtils.rm_f "/tmp/after_script"
        end

        it "runs the before script" do
          call
          expect(File.exists?("/tmp/before_script")).to eq(true)
        end

        it "runs the after script" do
          call
          expect(File.exists?("/tmp/after_script")).to eq(true)
        end
      end

      it "requests the http challenge" do
        call
        expect(http_challenge).to have_received(:request_validation)
      end

      it "answers the http challenge" do
        call
        expect(http_solver).to have_received(:solve)
      end

      it "obtains and writes the certificate" do
        call
        expect(File.read(certificate_path)).to eq("certificate")
      end

      it "cleans up the http challenge" do
        call
        expect(http_solver).to have_received(:cleanup)
      end
    end

    describe "#update_dns" do
      let(:call) { subject.update_dns(aws_region: "region", aws_access_key: "access key", aws_secret_key: "secret key") }

      context "with scripts" do
        let(:before_script) { "touch /tmp/before_script" }
        let(:after_script) { "touch /tmp/after_script" }

        after do
          FileUtils.rm_f "/tmp/before_script"
          FileUtils.rm_f "/tmp/after_script"
        end

        it "runs the before script" do
          call
          expect(File.exists?("/tmp/before_script")).to eq(true)
        end

        it "runs the after script" do
          call
          expect(File.exists?("/tmp/after_script")).to eq(true)
        end
      end

      it "requests the dns challenge" do
        call
        expect(dns_challenge).to have_received(:request_validation)
      end

      it "answers the dns challenge" do
        call
        expect(dns_solver).to have_received(:solve)
      end

      it "obtains and writes the certificate" do
        call
        expect(File.read(certificate_path)).to eq("certificate")
      end

      it "cleans up the dns challenge" do
        call
        expect(dns_solver).to have_received(:cleanup)
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
      let(:call) { subject.write(private_key: "private key", certificate: "certificate") }

      let(:before_script) { "touch /tmp/before_script" }
      let(:after_script) { "touch /tmp/after_script" }

      after do
        FileUtils.rm_f "/tmp/before_script"
        FileUtils.rm_f "/tmp/after_script"
      end

      context "with existing private key and certificate" do
        before { subject.write(private_key: "old private key", certificate: "old certificate") }

        it "update the private key" do
          call
          expect(File.read(private_key_path)).to eq("private key")
        end

        it "updates the certificate" do
          call
          expect(File.read(certificate_path)).to eq("certificate")
        end

        it "updates the full file" do
          call
          expect(File.read(full_path)).to eq("certificate\nprivate key")
        end
      end

      context "with existing and matching private key and certificate" do
        before do
          subject.write(private_key: "private key", certificate: "certificate")

          FileUtils.rm_f "/tmp/before_script"
          FileUtils.rm_f "/tmp/after_script"
        end

        it "does not run the before script" do
          call
          expect(File.exists?("/tmp/before_script")).to eq(false)
        end

        it "does not run the after script" do
          call
          expect(File.exists?("/tmp/after_script")).to eq(false)
        end
      end

      it "runs the before script" do
        call
        expect(File.exists?("/tmp/before_script")).to eq(true)
      end

      it "runs the after script" do
        call
        expect(File.exists?("/tmp/after_script")).to eq(true)
      end

      it "writes the private key" do
        call
        expect(File.read(private_key_path)).to eq("private key")
      end

      it "writes the certificate" do
        call
        expect(File.read(certificate_path)).to eq("certificate")
      end

      it "writes the full file" do
        call
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
end
