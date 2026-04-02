# frozen_string_literal: true

class DeliveryController < ApplicationController
  layout "public"
  after_action :prevent_delivery_caching

  # GET /delivery/:token
  def show
    @delivery_token = DeliveryToken.find_by_token(params[:token])

    if @delivery_token.nil?
      AuditLog.log(
        action: "delivery_token_invalid",
        actor_type: "recipient",
        metadata: { reason: "not_found" },
        request: request
      )
      flash[:alert] = "Invalid or revoked delivery link."
      redirect_to login_path
      return
    end

    @recipient = @delivery_token.recipient
    @sender = @recipient.user

    # Get message recipients with their availability status
    @message_recipients = @recipient.message_recipients
      .joins(:message)
      .where(messages: { user_id: @sender.id })
      .includes(:message)

    @available_message_recipients = @message_recipients.select(&:available?)
    @pending_message_recipients = @message_recipients.reject(&:available?)

    # Record access
    @delivery_token.record_access!

    AuditLog.log(
      action: "delivery_link_opened",
      user: @sender,
      actor_type: "recipient",
      metadata: {
        recipient_id: @recipient.id,
        available_count: @available_message_recipients.count,
        pending_count: @pending_message_recipients.count
      },
      request: request
    )
  end

  # GET /delivery/:token/payload
  # Returns encrypted payloads for client-side decryption
  def payload
    delivery_token = DeliveryToken.find_by_token(params[:token])

    if delivery_token.nil?
      AuditLog.log(
        action: "delivery_token_invalid",
        actor_type: "recipient",
        metadata: { reason: "not_found" },
        request: request
      )
      render json: { error: "Invalid or revoked delivery link." }, status: :not_found
      return
    end

    recipient = delivery_token.recipient
    sender = recipient.user
    delivery_token.record_access!

    # Get only available message recipients
    available_mrs = recipient.message_recipients
      .joins(:message)
      .where(messages: { user_id: sender.id })
      .includes(:message)
      .select(&:available?)

    # Build payload for available messages only
    payloads = available_mrs.map do |mr|
      message = mr.message
      payload = message.delivery_payload_for(recipient)
      next nil unless payload

      {
        message_id: message.id,
        label: message.label,
        created_at: message.created_at.iso8601,
        **payload
      }
    end.compact

    render json: {
      recipient: {
        id: recipient.id,
        email: recipient.email,
        name: recipient.name
      },
      sender_email: sender.email,
      messages: payloads
    }
  end

  private

  def prevent_delivery_caching
    set_no_store_cache_headers
  end
end
