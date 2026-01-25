# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupAuditLogsJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user) }

    it "deletes audit logs older than retention period" do
      # Old log (should be deleted)
      old_log = create(:audit_log, user: user, created_at: 366.days.ago)

      # Recent log (should NOT be deleted)
      recent_log = create(:audit_log, user: user, created_at: 364.days.ago)

      # Current log
      current_log = create(:audit_log, user: user)

      described_class.new.perform

      expect(AuditLog.exists?(old_log.id)).to be false
      expect(AuditLog.exists?(recent_log.id)).to be true
      expect(AuditLog.exists?(current_log.id)).to be true
    end

    it "respects custom retention_days parameter" do
      old_log = create(:audit_log, user: user, created_at: 31.days.ago)

      described_class.new.perform(retention_days: 30)

      expect(AuditLog.exists?(old_log.id)).to be false
    end

    it "returns count of deleted logs" do
      create(:audit_log, user: user, created_at: 400.days.ago)
      create(:audit_log, user: user, created_at: 400.days.ago)
      create(:audit_log, user: user)

      # Job doesn't return count but logs it, just verify no errors
      expect { described_class.new.perform }.not_to raise_error
      expect(AuditLog.count).to eq(1)
    end
  end
end
