
require "aws-sdk-route53"
require "logger"

module Rencrypt
  class DnsSolver
    attr_reader :aws_endpoint, :aws_region, :aws_access_key, :aws_secret_key, :common_name, :record_name, :record_type, :record_content, :logger

    def initialize(aws_endpoint:, aws_region:, aws_access_key:, aws_secret_key:, common_name:, record_name:, record_type:, record_content:, logger: Logger.new("/dev/null"))
      @aws_endpoint = aws_endpoint
      @aws_region = aws_region
      @aws_access_key = aws_access_key
      @aws_secret_key = aws_secret_key
      @common_name = common_name
      @record_name = record_name
      @record_type = record_type
      @record_content = record_content
      @logger = logger
    end

    def solve
      wait_for route53.change_resource_record_sets({
        hosted_zone_id: hosted_zone.id,
        change_batch: {
          changes: [
            action: "UPSERT",
            resource_record_set: {
              name: full_record_name,
              type: record_type,
              resource_records: [
                value: record_content
              ],
              ttl: 60
            }
          ]
        }
      })
    end

    def cleanup
      wait_for route53.change_resource_record_sets({
        hosted_zone_id: hosted_zone.id,
        change_batch: {
          changes: [
            action: "DELETE",
            resource_record_set: {
              name: full_record_name,
              type: record_type,
              resource_records: [
                value: record_content
              ],
              ttl: 60
            }
          ]
        }
      })
    end

    private

    def wait_for(change_response)
      change_info = change_response.change_info

      until change_info.status == "INSYNC"
        logger.info "waiting for dns change to complete"

        sleep 5

        change_info = route53.get_change(id: change_info.id).change_info
      end
    end

    def full_record_name
      "#{record_name}.#{common_name}"
    end

    def hosted_zone
      @hosted_zone ||= hosted_zones.detect do |hosted_zone|
        common_name.end_with?(".#{hosted_zone.name.gsub(/\.$/, "")}")
      end
    end

    def hosted_zones
      return enum_for(:hosted_zones) unless block_given?

      marker = nil

      loop do
        response = route53.list_hosted_zones({ marker: marker }.compact)

        response.hosted_zones.each do |hosted_zone|
          yield hosted_zone
        end

        return unless response.is_truncated

        marker = response.next_marker
      end
    end

    def route53
      @route53 ||= Aws::Route53::Client.new(
        endpoint: aws_endpoint,
        region: aws_region,
        access_key_id: aws_access_key,
        secret_access_key: aws_secret_key
      )
    end
  end
end
