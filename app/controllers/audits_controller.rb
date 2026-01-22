# frozen_string_literal: true

class AuditsController < ApplicationController
  before_action :require_authentication

  def index
    @audit_logs = current_user.audit_logs.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.csv do
        send_data AuditLogCsv.new(@audit_logs).to_csv,
                  filename: "audit-log-#{Time.current.strftime('%Y%m%d-%H%M')}.csv"
      end
    end
  end
end
