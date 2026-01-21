# frozen_string_literal: true

class DeliveryController < ApplicationController
  layout "public"

  # GET /delivery/:token
  def show
    @delivery_token = DeliveryToken.find_by_token(params[:token])

    if @delivery_token.nil?
      flash[:alert] = "Invalid or revoked delivery link."
      redirect_to login_path
      return
    end

    @recipient = @delivery_token.recipient
    @sender = @recipient.user
    @messages = @recipient.messages.where(user: @sender)

    # Record access
    @delivery_token.record_access!

    AuditLog.log(
      action: "delivery_link_opened",
      user: @sender,
      actor_type: "recipient",
      metadata: { recipient_id: @recipient.id, messages_count: @messages.count },
      request: request
    )
  end

  # GET /delivery/:token/payload
  # Returns encrypted payloads for client-side decryption
  def payload
    delivery_token = DeliveryToken.find_by_token(params[:token])

    if delivery_token.nil?
      render json: { error: "Invalid or revoked delivery link." }, status: :not_found
      return
    end

    recipient = delivery_token.recipient
    sender = recipient.user
    messages = recipient.messages.where(user: sender)

    # Build payload for all messages
    payloads = messages.map do |message|
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
end
