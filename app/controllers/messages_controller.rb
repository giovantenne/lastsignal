# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_message, only: [ :show, :edit, :update, :destroy ]

  # GET /messages
  def index
    @messages = current_user.messages.includes(:recipients).order(created_at: :desc)
  end

  # GET /messages/new
  def new
    @message = current_user.messages.build
    @available_recipients = current_user.recipients.with_keys
  end

  # POST /messages
  def create
    had_active_messages = current_user.has_active_messages?
    # This is called from JavaScript with encrypted data
    recipient_envelopes = parse_recipient_envelopes
    unless recipients_valid?(recipient_envelopes)
      render json: { error: "Invalid recipient selection." }, status: :unprocessable_entity
      return
    end

    result = Message.create_encrypted(
      user: current_user,
      label: params[:label],
      ciphertext_b64u: params[:ciphertext_b64u],
      nonce_b64u: params[:nonce_b64u],
      recipient_envelopes: recipient_envelopes
    )

    AuditLog.log(
      action: "message_created",
      user: current_user,
      metadata: { message_id: result.id, recipients_count: result.recipients.count },
      request: request
    )

    if !had_active_messages && current_user.has_active_messages?
      current_user.resume_checkins_for_messages!
      AuditLog.log(
        action: "checkin_resumed_for_messages",
        user: current_user,
        actor_type: "system",
        metadata: { message_id: result.id },
        request: request
      )
    end

    render json: { success: true, message_id: result.id, redirect_url: messages_path }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Message creation failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if Rails.env.development? || Rails.env.test?
    render json: { error: "Failed to save message" }, status: :internal_server_error
  end

  # GET /messages/:id
  def show
    @recipients = @message.message_recipients.includes(recipient: :recipient_key)
  end

  # GET /messages/:id/edit
  def edit
    @available_recipients = current_user.recipients.with_keys
    @current_recipient_ids = @message.recipient_ids
  end

  # PATCH/PUT /messages/:id
  def update
    had_active_messages = current_user.has_active_messages?
    recipient_envelopes = parse_recipient_envelopes
    unless recipients_valid?(recipient_envelopes)
      render json: { error: "Invalid recipient selection." }, status: :unprocessable_entity
      return
    end

    @message.update_encrypted(
      label: params[:label],
      ciphertext_b64u: params[:ciphertext_b64u],
      nonce_b64u: params[:nonce_b64u],
      recipient_envelopes: recipient_envelopes
    )

    AuditLog.log(
      action: "message_updated",
      user: current_user,
      metadata: { message_id: @message.id },
      request: request
    )

    if !had_active_messages && current_user.has_active_messages?
      current_user.resume_checkins_for_messages!
      AuditLog.log(
        action: "checkin_resumed_for_messages",
        user: current_user,
        actor_type: "system",
        metadata: { message_id: @message.id },
        request: request
      )
    end

    render json: { success: true, message_id: @message.id, redirect_url: message_path(@message) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Message update failed: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if Rails.env.development? || Rails.env.test?
    render json: { error: "Failed to update message" }, status: :internal_server_error
  end

  # DELETE /messages/:id
  def destroy
    @message.destroy!

    AuditLog.log(
      action: "message_deleted",
      user: current_user,
      metadata: {},
      request: request
    )

    flash[:notice] = "Message deleted."
    redirect_to messages_path
  end

  private

  def set_message
    @message = current_user.messages.find(params[:id])
  end

  def parse_recipient_envelopes
    envelopes = params[:recipient_envelopes]
    return [] if envelopes.blank?

    envelopes = JSON.parse(envelopes) if envelopes.is_a?(String)

    envelopes.map do |env|
      {
        recipient_id: env["recipient_id"].to_i,
        encrypted_msg_key_b64u: env["encrypted_msg_key_b64u"],
        envelope_algo: env["envelope_algo"] || "crypto_box_seal",
        envelope_version: env["envelope_version"] || 1,
        delivery_delay_hours: (env["delivery_delay_days"].to_i * 24)
      }
    end
  end

  def recipients_valid?(envelopes)
    recipient_ids = envelopes.map { |env| env[:recipient_id] }.uniq
    return false if recipient_ids.empty?

    current_user.recipients.where(id: recipient_ids).count == recipient_ids.size
  end
end
