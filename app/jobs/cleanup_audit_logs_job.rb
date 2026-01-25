# frozen_string_literal: true

class CleanupAuditLogsJob < ApplicationJob
  queue_as :default

  # Cleanup audit logs older than the retention period
  # Default: 365 days
  RETENTION_DAYS = 365

  def perform(retention_days: RETENTION_DAYS)
    Rails.logger.info "[CleanupAuditLogsJob] Starting audit log cleanup (retention: #{retention_days} days)"

    threshold = retention_days.days.ago
    deleted_count = AuditLog.where("created_at < ?", threshold).delete_all

    Rails.logger.info "[CleanupAuditLogsJob] Deleted #{deleted_count} audit logs older than #{threshold}"
  end
end
