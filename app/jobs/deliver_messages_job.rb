# frozen_string_literal: true

class DeliverMessagesJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find(user_id)

    return unless user.delivered?

    Rails.logger.info "[DeliverMessagesJob] Delivering messages for user #{user_id}"

    # Get all recipients with accepted keys
    recipients_with_messages = user.recipients.with_keys.includes(:messages)

    recipients_with_messages.find_each do |recipient|
      messages = recipient.messages.where(user: user)
      next if messages.empty?

      # Generate delivery token
      delivery_token, raw_token = DeliveryToken.generate_for(recipient)

      # Send delivery email
      RecipientMailer.delivery(recipient, raw_token, messages.count).deliver_later

      AuditLog.log(
        action: "recipient_delivery_sent",
        user: user,
        actor_type: "system",
        metadata: { recipient_id: recipient.id, messages_count: messages.count }
      )

      Rails.logger.info "[DeliverMessagesJob] Sent delivery email to recipient #{recipient.id} with #{messages.count} messages"
    end
  end
end
