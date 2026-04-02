# frozen_string_literal: true

class TrustedContactsController < ApplicationController
  layout "public"
  after_action :prevent_trusted_contact_caching

  # GET /trusted_contact/:token
  def show
    @trusted_contact = TrustedContact.find_by_token(params[:token])

    if @trusted_contact.nil?
      AuditLog.log(
        action: "trusted_contact_token_invalid",
        actor_type: "trusted_contact",
        metadata: { reason: "not_found" },
        request: request
      )
      flash[:alert] = "Invalid or expired trusted contact link."
      redirect_to login_path
      return
    end

    @user = @trusted_contact.user
  end

  # POST /trusted_contact/:token/confirm
  def confirm
    trusted_contact = TrustedContact.find_by_token(params[:token])

    if trusted_contact.nil?
      AuditLog.log(
        action: "trusted_contact_token_invalid",
        actor_type: "trusted_contact",
        metadata: { reason: "not_found" },
        request: request
      )
      flash[:alert] = "Invalid or expired trusted contact link."
      redirect_to login_path
      return
    end

    token_stale = false

    TrustedContact.transaction do
      trusted_contact.lock!

      unless trusted_contact_token_current?(trusted_contact, params[:token])
        token_stale = true
        raise ActiveRecord::Rollback
      end

      trusted_contact.confirm!
    end

    if token_stale
      AuditLog.log(
        action: "trusted_contact_token_invalid",
        user: trusted_contact.user,
        actor_type: "trusted_contact",
        metadata: { reason: "stale" },
        request: request
      )
      flash[:alert] = "Invalid or expired trusted contact link."
      redirect_to login_path
      return
    end

    AuditLog.log(
      action: "trusted_contact_pause_set",
      user: trusted_contact.user,
      actor_type: "trusted_contact",
      metadata: { trusted_contact_id: trusted_contact.id, paused_until: trusted_contact.paused_until&.iso8601 },
      request: request
    )

    AuditLog.log(
      action: "trusted_contact_confirmed",
      user: trusted_contact.user,
      actor_type: "trusted_contact",
      metadata: { trusted_contact_id: trusted_contact.id, paused_until: trusted_contact.paused_until&.iso8601 },
      request: request
    )

    TrustedContactMailer.confirmation_notice(trusted_contact.user, trusted_contact).deliver_later

    AuditLog.log(
      action: "trusted_contact_confirmation_notice_sent",
      user: trusted_contact.user,
      actor_type: "system",
      metadata: { trusted_contact_id: trusted_contact.id }
    )
    @trusted_contact = trusted_contact
    @user = trusted_contact.user
    render :success
  end

  private

  def trusted_contact_token_current?(trusted_contact, raw_token)
    digest = trusted_contact.token_digest
    expires_at = trusted_contact.token_expires_at

    return false if digest.blank? || expires_at.blank? || expires_at <= Time.current

    current_digest = Digest::SHA256.hexdigest(raw_token.to_s)
    return false unless digest.bytesize == current_digest.bytesize

    ActiveSupport::SecurityUtils.secure_compare(digest, current_digest)
  end

  def prevent_trusted_contact_caching
    set_no_store_cache_headers
  end
end
