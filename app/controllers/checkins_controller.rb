# frozen_string_literal: true

class CheckinsController < ApplicationController
  include ActionView::Helpers::DateHelper

  layout "public"

  before_action :load_user_from_token, except: :success

  # GET /checkin/confirm/:token
  def confirm
    @token = params[:token]
  end

  # POST /checkin/confirm/:token
  def complete
    @user.confirm_checkin!

    AuditLog.log(
      action: "checkin_confirmed",
      user: @user,
      actor_type: "user",
      metadata: { next_checkin_at: @user.next_checkin_at&.iso8601 },
      request: request
    )

    flash[:notice] = "Check-in confirmed! Your next check-in is due #{distance_of_time_in_words(Time.current, @user.next_checkin_at)} from now."
    redirect_to checkin_success_path
  end

  def success
  end

  private

  def load_user_from_token
    token = params[:token].presence || params[:checkin_token].presence
    token_digest = Digest::SHA256.hexdigest(token.to_s)

    user = User.find_by(checkin_token_digest: token_digest)

    if user.nil?
      AuditLog.log(
        action: "checkin_token_invalid",
        actor_type: "user",
        metadata: { reason: "not_found" },
        request: request
      )

      flash[:alert] = "Invalid or expired check-in link."
      redirect_to login_path
      return
    end

    if user.checkin_token_expires_at.blank? || user.checkin_token_expires_at <= Time.current
      AuditLog.log(
        action: "checkin_token_invalid",
        user: user,
        actor_type: "user",
        metadata: { reason: "expired" },
        request: request
      )

      user.update_columns(checkin_token_digest: nil, checkin_token_expires_at: nil)
      flash[:alert] = "Invalid or expired check-in link."
      redirect_to login_path
      return
    end

    @user = user
  end
end
