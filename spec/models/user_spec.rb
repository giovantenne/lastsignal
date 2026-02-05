# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should allow_value("user@example.com").for(:email) }
    it { should_not allow_value("invalid").for(:email) }
    it { should_not allow_value("invalid@").for(:email) }

    it "validates checkin_interval_days within bounds" do
      user = build(:user, checkin_interval_hours: 0)
      expect(user).not_to be_valid
      expect(user.errors[:checkin_interval_days]).to be_present
    end

    it "validates checkin_attempts within bounds" do
      user = build(:user, checkin_attempts: 0)
      expect(user).not_to be_valid
      expect(user.errors[:checkin_attempts]).to be_present
    end

    it "validates checkin_attempt_interval_days within bounds" do
      user = build(:user, checkin_attempt_interval_hours: 0)
      expect(user).not_to be_valid
      expect(user.errors[:checkin_attempt_interval_days]).to be_present
    end
  end

  describe "associations" do
    it { should have_many(:magic_link_tokens).dependent(:destroy) }
    it { should have_many(:messages).dependent(:destroy) }
    it { should have_many(:recipients).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:nullify) }
  end

  describe "enums" do
    it { should define_enum_for(:state).with_values(active: "active", grace: "grace", cooldown: "cooldown", delivered: "delivered", paused: "paused").backed_by_column_of_type(:string) }
  end

  describe "callbacks" do
    describe "normalize_email" do
      it "downcases email" do
        user = create(:user, email: "USER@EXAMPLE.COM")
        expect(user.email).to eq("user@example.com")
      end

      it "strips whitespace" do
        user = create(:user, email: "  user@example.com  ")
        expect(user.email).to eq("user@example.com")
      end
    end

    describe "schedule_first_checkin" do
      it "sets next_checkin_at after create" do
        user = create(:user)
        expect(user.next_checkin_at).to be > Time.current
      end
    end
  end

  describe "scopes" do
    describe ".needing_initial_attempt" do
      it "includes active users past their checkin time" do
        user = create(:user, :needs_checkin)
        expect(User.needing_initial_attempt).to include(user)
      end

      it "excludes active users before their checkin time" do
        user = create(:user, next_checkin_at: 1.hour.from_now)
        expect(User.needing_initial_attempt).not_to include(user)
      end

      it "excludes users in other states" do
        user = create(:user, :in_grace)
        expect(User.needing_initial_attempt).not_to include(user)
      end
    end

    describe ".needing_followup_attempt" do
      it "includes grace users past their attempt interval" do
        user = create(:user, :in_grace, last_checkin_attempt_at: 8.days.ago, checkin_attempt_interval_hours: 168)
        expect(User.needing_followup_attempt).to include(user)
      end

      it "excludes grace users before their attempt interval" do
        user = create(:user, :in_grace, last_checkin_attempt_at: 1.hour.ago, checkin_attempt_interval_hours: 168)
        expect(User.needing_followup_attempt).not_to include(user)
      end
    end

    describe ".needing_delivery" do
      it "includes cooldown users past their attempt interval" do
        user = create(:user, :in_cooldown, cooldown_warning_sent_at: 8.days.ago, checkin_attempt_interval_hours: 168)
        expect(User.needing_delivery).to include(user)
      end

      it "excludes cooldown users before their attempt interval" do
        user = create(:user, :in_cooldown, cooldown_warning_sent_at: 1.hour.ago, checkin_attempt_interval_hours: 168)
        expect(User.needing_delivery).not_to include(user)
      end
    end
  end

  describe "instance methods" do
    describe "#effective_checkin_interval_hours" do
      it "returns user value when set" do
        user = build(:user, checkin_interval_hours: 100)
        expect(user.effective_checkin_interval_hours).to eq(100)
      end

      it "returns system default when nil" do
        user = build(:user, checkin_interval_hours: nil)
        expect(user.effective_checkin_interval_hours).to eq(AppConfig.checkin_default_interval_hours)
      end
    end

    describe "#effective_checkin_attempts" do
      it "returns user value when set" do
        user = build(:user, checkin_attempts: 5)
        expect(user.effective_checkin_attempts).to eq(5)
      end

      it "returns system default when nil" do
        user = build(:user, checkin_attempts: nil)
        expect(user.effective_checkin_attempts).to eq(AppConfig.checkin_default_attempts)
      end
    end

    describe "#effective_checkin_attempt_interval_hours" do
      it "returns user value when set" do
        user = build(:user, checkin_attempt_interval_hours: 200)
        expect(user.effective_checkin_attempt_interval_hours).to eq(200)
      end

      it "returns system default when nil" do
        user = build(:user, checkin_attempt_interval_hours: nil)
        expect(user.effective_checkin_attempt_interval_hours).to eq(AppConfig.checkin_default_attempt_interval_hours)
      end
    end

    describe "#confirm_checkin!" do
      it "resets state to active" do
        user = create(:user, :in_grace)
        user.confirm_checkin!
        expect(user.state).to eq("active")
      end

      it "updates last_checkin_confirmed_at" do
        user = create(:user, :in_grace)
        freeze_time do
          user.confirm_checkin!
          expect(user.last_checkin_confirmed_at).to eq(Time.current)
        end
      end

      it "schedules next checkin" do
        user = create(:user, :in_grace, checkin_interval_hours: 168)
        freeze_time do
          user.confirm_checkin!
          expect(user.next_checkin_at).to eq(Time.current + 168.hours)
        end
      end

      it "clears attempt tracking and delivered timestamps" do
        user = create(
          :user,
          :in_grace,
          checkin_attempts_sent: 3,
          last_checkin_attempt_at: 2.days.ago,
          delivered_at: 2.days.ago
        )
        user.confirm_checkin!
        expect(user.last_checkin_attempt_at).to be_nil
        expect(user.checkin_attempts_sent).to eq(0)
        expect(user.delivered_at).to be_nil
      end

      it "does not reactivate delivered users" do
        user = create(:user, :delivered, delivered_at: Time.current)
        delivered_at = user.delivered_at

        expect { user.confirm_checkin! }.not_to change(user, :state)
        expect(user.reload.delivered_at).to eq(delivered_at)
      end
    end

    describe "#mark_delivered!" do
      it "transitions from cooldown to delivered" do
        user = create(:user, :in_cooldown)
        user.mark_delivered!
        expect(user.state).to eq("delivered")
      end

      it "sets delivered_at" do
        user = create(:user, :in_cooldown)
        freeze_time do
          user.mark_delivered!
          expect(user.delivered_at).to eq(Time.current)
        end
      end

      it "does nothing if not in cooldown" do
        user = create(:user, :in_grace)
        user.mark_delivered!
        expect(user.state).to eq("grace")
      end
    end

    describe "#next_attempt_due_at" do
      it "calculates the next attempt time" do
        user = build(:user, last_checkin_attempt_at: Time.current, checkin_attempt_interval_hours: 48)
        expect(user.next_attempt_due_at).to eq(user.last_checkin_attempt_at + 48.hours)
      end

      it "returns nil without last attempt" do
        user = build(:user, last_checkin_attempt_at: nil)
        expect(user.next_attempt_due_at).to be_nil
      end
    end

    describe "#delivery_due_at" do
      it "returns the delivery time from cooldown warning" do
        user = build(:user, :in_cooldown, cooldown_warning_sent_at: Time.current, checkin_attempt_interval_hours: 48)
        expect(user.delivery_due_at).to eq(user.cooldown_warning_sent_at + 48.hours)
      end

      it "returns nil when not in cooldown" do
        user = build(:user, cooldown_warning_sent_at: Time.current)
        expect(user.delivery_due_at).to be_nil
      end
    end

    describe "#generate_recovery_code!" do
      it "returns a formatted recovery code" do
        user = create(:user)
        code = user.generate_recovery_code!
        expect(code).to match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}\z/)
      end

      it "stores a digest of the code" do
        user = create(:user)
        code = user.generate_recovery_code!
        expect(user.recovery_code_digest).to be_present
        # Verify it's a valid SHA256 hex digest
        expect(user.recovery_code_digest).to match(/\A[a-f0-9]{64}\z/)
      end

      it "clears recovery_code_viewed_at" do
        user = create(:user)
        user.update!(recovery_code_viewed_at: Time.current)
        user.generate_recovery_code!
        expect(user.recovery_code_viewed_at).to be_nil
      end
    end

    describe "#verify_recovery_code" do
      it "returns true for correct code" do
        user = create(:user)
        code = user.generate_recovery_code!
        expect(user.verify_recovery_code(code)).to be true
      end

      it "returns true for code without dashes" do
        user = create(:user)
        code = user.generate_recovery_code!
        expect(user.verify_recovery_code(code.delete("-"))).to be true
      end

      it "returns true for lowercase code" do
        user = create(:user)
        code = user.generate_recovery_code!
        expect(user.verify_recovery_code(code.downcase)).to be true
      end

      it "returns false for incorrect code" do
        user = create(:user)
        user.generate_recovery_code!
        expect(user.verify_recovery_code("WRONG-CODE-HERE-1234")).to be false
      end

      it "returns false if no recovery code set" do
        user = create(:user)
        user.update_column(:recovery_code_digest, nil)
        expect(user.verify_recovery_code("XXXX-XXXX-XXXX-XXXX")).to be false
      end
    end

    describe "#use_recovery_code!" do
      it "returns new code on success" do
        user = create(:user, :in_cooldown)
        old_code = user.generate_recovery_code!
        new_code = user.use_recovery_code!(old_code)
        expect(new_code).to be_present
        expect(new_code).not_to eq(old_code)
      end

      it "sets user to paused state" do
        user = create(:user, :in_cooldown)
        code = user.generate_recovery_code!
        user.use_recovery_code!(code)
        expect(user.reload.state).to eq("paused")
      end

      it "returns nil on invalid code" do
        user = create(:user, :in_cooldown)
        user.generate_recovery_code!
        result = user.use_recovery_code!("WRONG-CODE-1234-5678")
        expect(result).to be_nil
      end

      it "invalidates old code after use" do
        user = create(:user, :in_cooldown)
        old_code = user.generate_recovery_code!
        user.use_recovery_code!(old_code)
        expect(user.verify_recovery_code(old_code)).to be false
      end
    end

    describe "#recovery_code_viewed?" do
      it "returns false when not viewed" do
        user = create(:user)
        expect(user.recovery_code_viewed?).to be false
      end

      it "returns true when viewed" do
        user = create(:user)
        user.update!(recovery_code_viewed_at: Time.current)
        expect(user.recovery_code_viewed?).to be true
      end
    end

    describe "#mark_recovery_code_viewed!" do
      it "sets recovery_code_viewed_at" do
        user = create(:user)
        freeze_time do
          user.mark_recovery_code_viewed!
          expect(user.recovery_code_viewed_at).to eq(Time.current)
        end
      end

      it "does not update if already viewed" do
        user = create(:user)
        user.update!(recovery_code_viewed_at: 1.day.ago)
        original_time = user.recovery_code_viewed_at
        user.mark_recovery_code_viewed!
        expect(user.recovery_code_viewed_at).to eq(original_time)
      end
    end

    describe "#pause!" do
      it "sets state to paused from active" do
        user = create(:user)
        user.pause!
        expect(user.reload.state).to eq("paused")
      end

      it "sets state to paused from grace" do
        user = create(:user, :in_grace)
        user.pause!
        expect(user.reload.state).to eq("paused")
      end

      it "sets state to paused from cooldown" do
        user = create(:user, :in_cooldown)
        user.pause!
        expect(user.reload.state).to eq("paused")
      end

      it "clears attempt tracking" do
        user = create(:user, :in_cooldown, last_checkin_attempt_at: 2.hours.ago, checkin_attempts_sent: 2)
        user.pause!
        user.reload
        expect(user.last_checkin_attempt_at).to be_nil
        expect(user.checkin_attempts_sent).to eq(0)
        expect(user.next_checkin_at).to be_nil
      end

      it "does nothing if already paused" do
        user = create(:user)
        user.pause!
        original_updated_at = user.updated_at
        sleep(0.01)
        user.pause!
        expect(user.reload.updated_at).to eq(original_updated_at)
      end

      it "does not pause delivered users" do
        user = create(:user, :delivered)
        user.pause!
        expect(user.reload.state).to eq("delivered")
      end
    end

    describe "#unpause!" do
      it "sets state to active from paused" do
        user = create(:user)
        user.pause!
        user.unpause!
        expect(user.reload.state).to eq("active")
      end

      it "schedules next check-in" do
        user = create(:user)
        user.pause!
        freeze_time do
          user.unpause!
          expect(user.reload.next_checkin_at).to eq(Time.current + user.effective_checkin_interval_hours.hours)
        end
      end

      it "does nothing if not paused" do
        user = create(:user)
        expect(user.state).to eq("active")
        user.unpause!
        expect(user.reload.state).to eq("active")
      end
    end
  end
end
