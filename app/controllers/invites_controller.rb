# frozen_string_literal: true

class InvitesController < ApplicationController
  layout "public"
  after_action :prevent_invite_caching

  # GET /invites/:token
  def show
    @recipient = Recipient.find_by_invite_token(params[:token])

    if @recipient.nil?
      AuditLog.log(
        action: "invite_token_invalid",
        actor_type: "recipient",
        metadata: { reason: "not_found" },
        request: request
      )
      flash[:alert] = "Invalid invite link."
      redirect_to login_path
      return
    end

    unless @recipient.invite_valid?
      AuditLog.log(
        action: "invite_token_invalid",
        user: @recipient.user,
        actor_type: "recipient",
        metadata: { reason: "expired" },
        request: request
      )
      if @recipient.accepted?
        flash[:notice] = "You've already accepted this invite."
      else
        flash[:alert] = "This invite has expired. Please ask the sender to resend it."
      end
      redirect_to login_path
      return
    end

    @sender_email = @recipient.user.email
    @kdf_params = AppConfig.kdf_params
    @kdf_salt_b64u = generate_kdf_salt
  end

  # POST /invites/:token
  def accept
    @recipient = Recipient.find_by_invite_token(params[:token])

    if @recipient.nil?
      AuditLog.log(
        action: "invite_token_invalid",
        actor_type: "recipient",
        metadata: { reason: "not_found" },
        request: request
      )
      render json: { error: "Invalid invite link." }, status: :not_found
      return
    end

    unless @recipient.invite_valid?
      AuditLog.log(
        action: "invite_token_invalid",
        user: @recipient.user,
        actor_type: "recipient",
        metadata: { reason: "expired" },
        request: request
      )
      render json: { error: "This invite has expired or was already used." }, status: :gone
      return
    end

    # Validate required params
    public_key_b64u = params[:public_key_b64u]
    kdf_salt_b64u = params[:kdf_salt_b64u]
    kdf_params = params[:kdf_params]
    passphrase_hint = params[:passphrase_hint]

    if public_key_b64u.blank? || kdf_salt_b64u.blank? || kdf_params.blank?
      render json: { error: "Missing required parameters." }, status: :unprocessable_entity
      return
    end

    begin
      # Parse kdf_params if it's a string
      kdf_params = JSON.parse(kdf_params) if kdf_params.is_a?(String)
    rescue JSON::ParserError
      render json: { error: "Invalid key derivation parameters." }, status: :unprocessable_entity
      return
    end

    begin
      token_stale = false

      Recipient.transaction do
        @recipient.lock!

        unless invite_token_current?(@recipient, params[:token]) && @recipient.invite_valid?
          token_stale = true
          raise ActiveRecord::Rollback
        end

        @recipient.accept!(
          public_key_b64u: public_key_b64u,
          kdf_salt_b64u: kdf_salt_b64u,
          kdf_params: kdf_params,
          passphrase_hint: passphrase_hint
        )
      end

      if token_stale
        AuditLog.log(
          action: "invite_token_invalid",
          user: @recipient.user,
          actor_type: "recipient",
          metadata: { reason: "stale" },
          request: request
        )
        render json: { error: "This invite has expired or was already used." }, status: :gone
        return
      end

      AuditLog.log(
        action: "recipient_accepted",
        user: @recipient.user,
        metadata: { recipient_id: @recipient.id },
        request: request
      )

      # Notify the sender that their recipient has accepted
      RecipientMailer.accepted_notice(@recipient).deliver_later

      render json: { success: true, message: "Your encryption key has been registered." }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def invite_token_current?(recipient, raw_token)
    digest = recipient.invite_token_digest
    return false if digest.blank?

    current_digest = Digest::SHA256.hexdigest(raw_token.to_s)
    return false unless digest.bytesize == current_digest.bytesize

    ActiveSupport::SecurityUtils.secure_compare(digest, current_digest)
  end

  def generate_kdf_salt
    # Generate 16 bytes of random salt, encode as base64url
    Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false)
  end

  def prevent_invite_caching
    set_no_store_cache_headers
  end
end
