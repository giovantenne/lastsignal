# frozen_string_literal: true

module Webhooks
  class EmailEventsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_webhook_secret

    # POST /webhooks/email_events
    def create
      # Parse the incoming event
      provider = params[:provider] || "generic"
      event_type = params[:event_type]
      message_id = params[:message_id]
      recipient_email = params[:recipient_email]
      timestamp = params[:timestamp]

      # Validate required fields
      unless event_type.present?
        render json: { error: "Missing event_type" }, status: :unprocessable_entity
        return
      end

      # Normalize event type
      normalized_event_type = normalize_event_type(event_type)

      unless EmailEvent::EVENT_TYPES.include?(normalized_event_type)
        Rails.logger.warn "[Webhook] Unknown event type: #{event_type}"
        normalized_event_type = "delivered" # Default fallback
      end

      # Hash email for privacy
      recipient_email_hash = recipient_email.present? ? Digest::SHA256.hexdigest(recipient_email.downcase) : nil

      # Store the event
      EmailEvent.create!(
        provider: provider,
        event_type: normalized_event_type,
        message_id: message_id,
        recipient_email_hash: recipient_email_hash,
        event_timestamp: parse_timestamp(timestamp),
        raw_json: filter_raw_payload(params.to_unsafe_h.except(:controller, :action))
      )

      Rails.logger.info "[Webhook] Recorded email event: #{normalized_event_type} for message #{message_id}"

      render json: { success: true }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[Webhook] Failed to save email event: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def verify_webhook_secret
      expected_secret = AppConfig.email_webhook_secret
      
      # Skip verification if no secret configured (development)
      return if expected_secret.blank?

      provided_secret = request.headers["X-Webhook-Secret"] || params[:webhook_secret]

      unless ActiveSupport::SecurityUtils.secure_compare(provided_secret.to_s, expected_secret)
        Rails.logger.warn "[Webhook] Invalid webhook secret"
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def normalize_event_type(event_type)
      case event_type.to_s.downcase
      when "delivered", "delivery"
        "delivered"
      when "bounced", "bounce", "hard_bounce", "soft_bounce"
        "bounced"
      when "complained", "complaint", "spam"
        "complained"
      when "opened", "open"
        "opened"
      when "clicked", "click"
        "clicked"
      when "deferred", "delayed"
        "deferred"
      else
        event_type.to_s.downcase
      end
    end

    def parse_timestamp(timestamp)
      return nil if timestamp.blank?

      case timestamp
      when Integer, Float
        Time.at(timestamp).utc
      when String
        Time.parse(timestamp).utc rescue nil
      else
        nil
      end
    end

    def filter_raw_payload(payload)
      sensitive_keys = %w[email recipient_email headers authorization token secret password passphrase]

      case payload
      when Hash
        payload.each_with_object({}) do |(key, value), filtered|
          key_name = key.to_s.downcase
          next if sensitive_keys.any? { |sensitive| key_name.include?(sensitive) }

          filtered[key] = filter_raw_payload(value)
        end
      when Array
        payload.map { |value| filter_raw_payload(value) }
      else
        payload
      end
    end
  end
end
