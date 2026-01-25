# frozen_string_literal: true

class CleanupExpiredTokensJob < ApplicationJob
  queue_as :default

  # Cleanup expired tokens older than the specified threshold
  # Default: 24 hours after expiration (gives buffer for debugging)
  def perform(older_than_hours: 24)
    Rails.logger.info "[CleanupExpiredTokensJob] Starting token cleanup"

    deleted_magic_links = cleanup_magic_link_tokens(older_than_hours)
    deleted_invite_tokens = cleanup_expired_invites(older_than_hours)

    Rails.logger.info "[CleanupExpiredTokensJob] Completed: " \
                      "#{deleted_magic_links} magic link tokens, " \
                      "#{deleted_invite_tokens} expired invites"
  end

  private

  def cleanup_magic_link_tokens(older_than_hours)
    threshold = older_than_hours.hours.ago
    MagicLinkToken.where("expires_at < ?", threshold).delete_all
  end

  def cleanup_expired_invites(older_than_hours)
    threshold = older_than_hours.hours.ago
    # Clear invite tokens for recipients whose invite expired
    # Keep the recipient record, just clear the token
    Recipient.where(state: "invited")
             .where("invite_expires_at < ?", threshold)
             .update_all(invite_token_digest: nil)
  end
end
