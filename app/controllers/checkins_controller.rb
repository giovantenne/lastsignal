# frozen_string_literal: true

class CheckinsController < ApplicationController
  include ActionView::Helpers::DateHelper

  layout "public"

  before_action :load_user_from_token, except: :success
  after_action :prevent_public_checkin_caching

  # GET /checkin/confirm/:token
  def confirm
    @token = params[:token]
  end

  # POST /checkin/confirm/:token
  def complete
    token_stale = false

    # Pessimistic lock to prevent race condition with ProcessCheckinsJob#mark_delivered!
    User.transaction do
      @user.lock!
      unless current_checkin_token_valid_for_user?
        token_stale = true
        raise ActiveRecord::Rollback
      end

      @user.confirm_checkin!
    end

    if token_stale
      AuditLog.log(
        action: "checkin_token_invalid",
        user: @user,
        actor_type: "user",
        metadata: { reason: "stale" },
        request: request
      )

      flash[:alert] = "Invalid or expired check-in link."
      redirect_to login_path
      return
    end

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

    if token.blank?
      flash[:alert] = "Invalid or expired check-in link."
      redirect_to login_path
      return
    end

    token_digest = Digest::SHA256.hexdigest(token)

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

    @user = user
    @token_digest = token_digest
  end

  def current_checkin_token_valid_for_user?
    digest = @user.checkin_token_digest
    return false if digest.blank?
    return false unless digest.bytesize == @token_digest.to_s.bytesize

    ActiveSupport::SecurityUtils.secure_compare(digest, @token_digest)
  end

  def prevent_public_checkin_caching
    set_no_store_cache_headers
  end
end
