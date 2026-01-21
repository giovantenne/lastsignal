# frozen_string_literal: true

class PanicRevokeController < ApplicationController
  layout "public"

  # GET /panic_revoke/:token
  def show
    @token = params[:token]
    token_digest = Digest::SHA256.hexdigest(@token.to_s)

    @user = User.find_by(panic_token_digest: token_digest)

    if @user.nil?
      flash[:alert] = "Invalid or expired panic revoke link."
      redirect_to login_path
      return
    end

    unless @user.cooldown?
      flash[:notice] = "Your account is not in cooldown. No action needed."
      redirect_to login_path
      return
    end

    @cooldown_ends_at = @user.cooldown_ends_at
  end

  # POST /panic_revoke/:token
  def confirm
    token = params[:token]
    token_digest = Digest::SHA256.hexdigest(token.to_s)

    user = User.find_by(panic_token_digest: token_digest)

    if user.nil?
      flash[:alert] = "Invalid or expired panic revoke link."
      redirect_to login_path
      return
    end

    unless user.cooldown?
      flash[:notice] = "Your account is not in cooldown. No action needed."
      redirect_to login_path
      return
    end

    # Execute panic revoke
    user.panic_revoke!

    # Clear the token
    user.update_column(:panic_token_digest, nil)

    AuditLog.log(
      action: "panic_revoke_used",
      user: user,
      actor_type: "user",
      metadata: { revoked_at: Time.current.iso8601 },
      request: request
    )

    flash[:notice] = "Delivery cancelled! You're back to active status. Your next check-in is scheduled."
    redirect_to logged_in? ? dashboard_path : login_path
  end
end
