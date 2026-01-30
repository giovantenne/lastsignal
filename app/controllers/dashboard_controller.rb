# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [ :acknowledge_recovery_code, :pause, :unpause ]

  def show
    @user = current_user
    @recipients_count = current_user.recipients.accepted.count
    @messages_count = current_user.messages.count
    @has_active_messages = current_user.has_active_messages?

    # Check if we need to show the recovery code
    @show_recovery_code = session[:show_recovery_code]
  end

  # POST /dashboard/acknowledge_recovery_code
  def acknowledge_recovery_code
    current_user.mark_recovery_code_viewed!
    session.delete(:show_recovery_code)
    flash[:notice] = "Recovery code saved. Keep it in a safe place!"
    redirect_to dashboard_path
  end

  # POST /dashboard/pause
  def pause
    if current_user.pause!
      AuditLog.log(
        action: "checkin_paused",
        user: current_user,
        actor_type: "user",
        request: request
      )
      flash[:notice] = "Check-ins paused. No reminders or deliveries will occur until you resume."
    else
      flash[:alert] = "Cannot pause check-ins in your current state."
    end
    redirect_to dashboard_path
  end

  # POST /dashboard/unpause
  def unpause
    if current_user.unpause!
      AuditLog.log(
        action: "checkin_resumed",
        user: current_user,
        actor_type: "user",
        request: request
      )
      flash[:notice] = "Check-ins resumed. Your next check-in is scheduled."
    else
      flash[:alert] = "Cannot resume check-ins in your current state."
    end
    redirect_to dashboard_path
  end
end
