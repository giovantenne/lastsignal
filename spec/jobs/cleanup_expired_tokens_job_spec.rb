# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupExpiredTokensJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user) }

    describe "magic link token cleanup" do
      it "deletes expired tokens older than threshold" do
        # Expired 25 hours ago (should be deleted with default 24h threshold)
        old_expired = create(:magic_link_token, user: user, expires_at: 25.hours.ago)

        # Expired 23 hours ago (should NOT be deleted with default 24h threshold)
        recent_expired = create(:magic_link_token, user: user, expires_at: 23.hours.ago)

        # Not expired yet
        valid_token = create(:magic_link_token, user: user, expires_at: 1.hour.from_now)

        described_class.new.perform

        expect(MagicLinkToken.exists?(old_expired.id)).to be false
        expect(MagicLinkToken.exists?(recent_expired.id)).to be true
        expect(MagicLinkToken.exists?(valid_token.id)).to be true
      end

      it "respects custom older_than_hours parameter" do
        old_expired = create(:magic_link_token, user: user, expires_at: 2.hours.ago)

        described_class.new.perform(older_than_hours: 1)

        expect(MagicLinkToken.exists?(old_expired.id)).to be false
      end
    end

    describe "expired invite cleanup" do
      it "clears invite tokens for expired invites" do
        recipient = create(:recipient, user: user)
        recipient.generate_invite_token!
        recipient.update!(invite_expires_at: 25.hours.ago)

        described_class.new.perform

        recipient.reload
        expect(recipient.invite_token_digest).to be_nil
        expect(recipient.state).to eq("invited") # State unchanged
      end

      it "does not clear tokens for non-expired invites" do
        recipient = create(:recipient, user: user)
        recipient.generate_invite_token!
        original_digest = recipient.invite_token_digest

        described_class.new.perform

        recipient.reload
        expect(recipient.invite_token_digest).to eq(original_digest)
      end

      it "does not affect accepted recipients" do
        recipient = create(:recipient, :accepted, user: user)
        original_state = recipient.state

        described_class.new.perform

        recipient.reload
        expect(recipient.state).to eq(original_state)
      end
    end
  end
end
