# frozen_string_literal: true

class ExternalCheckinsController < ActionController::API
  before_action :load_user_from_bearer_token

  def create
    accepted = false

    User.transaction do
      @user.lock!

      if @user.can_accept_external_checkin?
        @user.accept_external_checkin!
        accepted = true
      end
    end

    unless accepted
      render json: { error: "External check-ins are unavailable in the current account state." }, status: :conflict
      return
    end

    AuditLog.log(
      action: "external_checkin_received",
      user: @user,
      actor_type: "automation",
      metadata: { next_checkin_at: @user.next_checkin_at&.iso8601 },
      request: request
    )

    render json: { status: "ok", next_checkin_at: @user.next_checkin_at&.iso8601 }, status: :ok
  end

  private

  def load_user_from_bearer_token
    token = bearer_token

    if token.blank?
      log_invalid_token(reason: "missing")
      render json: { error: "Invalid external check-in token." }, status: :unauthorized
      return
    end

    @user = User.find_by_external_checkin_token(token)

    return if @user.present?

    log_invalid_token(reason: "not_found")
    render json: { error: "Invalid external check-in token." }, status: :unauthorized
  end

  def bearer_token
    authorization = request.authorization.to_s
    scheme, token = authorization.split(" ", 2)

    return nil unless scheme&.casecmp("Bearer")&.zero?

    token.presence
  end

  def log_invalid_token(reason:)
    AuditLog.log(
      action: "external_checkin_token_invalid",
      actor_type: "automation",
      metadata: { reason: reason },
      request: request
    )
  end
end
