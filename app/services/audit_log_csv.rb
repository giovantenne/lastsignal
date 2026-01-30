# frozen_string_literal: true

require "csv"

class AuditLogCsv
  HEADER = [ "timestamp", "action", "metadata" ].freeze

  def initialize(audit_logs)
    @audit_logs = audit_logs
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADER
      @audit_logs.find_each do |log|
        csv << [
          log.created_at&.iso8601,
          log.action,
          log.metadata.presence || ""
        ]
      end
    end
  end
end
