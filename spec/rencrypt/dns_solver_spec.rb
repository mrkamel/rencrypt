
require File.expand_path("../spec_helper", __dir__)
require "aws-sdk-route53"
require "socket"

module Rencrypt
  RSpec.describe DnsSolver do
    subject do
      described_class.new(
        aws_endpoint: "http://localhost:4580",
        aws_region: "eu-central-1",
        aws_access_key: "access_key",
        aws_secret_key: "secret_key",
        common_name: "common_name.test.host",
        record_name: "_acme-challenge",
        record_type: "TXT",
        record_content: "token"
      )
    end

    let(:route53) do
      Aws::Route53::Client.new(
        endpoint: "http://localhost:4580",
        region: "eu-central-1",
        access_key_id: "access_key",
        secret_access_key: "secret_key"
      )
    end

    let!(:hosted_zone) do
      route53.create_hosted_zone(name: "test.host", caller_reference: "Nonce").hosted_zone
    end

    after do
      route53.list_hosted_zones.hosted_zones.each do |hosted_zone|
        route53.delete_hosted_zone(id: hosted_zone.id)
      end
    end

    describe "#solve" do
      it "adds the specified record" do
        subject.solve

        resource_record_set = route53.list_resource_record_sets({ hosted_zone_id: hosted_zone.id }).resource_record_sets.first

        expect(resource_record_set.name).to eq("_acme-challenge.common_name.test.host")
        expect(resource_record_set.ttl).to eq(60)
        expect(resource_record_set.resource_records.first.value).to eq("\"token\"")
      end
    end

    describe "#cleanup" do
      it "removes the record" do
        subject.solve
        subject.cleanup

        expect(route53.list_resource_record_sets({ hosted_zone_id: hosted_zone.id }).resource_record_sets).to eq([])
      end
    end
  end
end
