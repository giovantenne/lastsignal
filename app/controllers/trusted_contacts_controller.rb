# frozen_string_literal: true

class TrustedContactsController < ApplicationController
  layout "public"

  # GET /trusted_contact/:token
  def show
    @trusted_contact = TrustedContact.find_by_token(params[:token])

    if @trusted_contact.nil?
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
      flash[:alert] = "Invalid or expired trusted contact link."
      redirect_to login_path
      return
    end

    trusted_contact.confirm!

    AuditLog.log(
      action: "trusted_contact_confirmed",
      user: trusted_contact.user,
      actor_type: "trusted_contact",
      metadata: { trusted_contact_id: trusted_contact.id, paused_until: trusted_contact.paused_until&.iso8601 },
      request: request
    )

    TrustedContactMailer.confirmation_notice(trusted_contact.user, trusted_contact).deliver_later

    @trusted_contact = trusted_contact
    @user = trusted_contact.user
    render :success
  end
end
