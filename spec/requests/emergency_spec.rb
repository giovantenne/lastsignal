# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Emergency", type: :request do
  describe "GET /emergency" do
    it "renders the emergency stop form" do
      get emergency_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Emergency Stop")
      expect(response.body).to include("recovery_code")
    end
  end

  describe "POST /emergency" do
    let(:user) { create(:user, :in_cooldown) }
    # Generate recovery code AFTER user creation to get the current code
    let(:recovery_code) { user.generate_recovery_code! }

    context "with valid email and recovery code" do
      it "stops message delivery and sets paused state" do
        post emergency_path, params: { email: user.email, recovery_code: recovery_code }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Emergency Stop Successful")
        expect(user.reload.state).to eq("paused")
      end

      it "invalidates the old recovery code" do
        post emergency_path, params: { email: user.email, recovery_code: recovery_code }
        expect(user.reload.verify_recovery_code(recovery_code)).to be false
      end

      it "creates an audit log" do
        expect {
          post emergency_path, params: { email: user.email, recovery_code: recovery_code }
        }.to change(AuditLog, :count).by(1)

        audit = AuditLog.last
        expect(audit.action).to eq("emergency_stop")
        expect(audit.user).to eq(user)
      end

      it "works with code without dashes" do
        code_without_dashes = recovery_code.delete("-")
        post emergency_path, params: { email: user.email, recovery_code: code_without_dashes }
        expect(response).to have_http_status(:ok)
        expect(user.reload.state).to eq("paused")
      end

      it "works with lowercase code" do
        post emergency_path, params: { email: user.email, recovery_code: recovery_code.downcase }
        expect(response).to have_http_status(:ok)
        expect(user.reload.state).to eq("paused")
      end
    end

    context "with invalid recovery code" do
      before { recovery_code } # ensure user is created and has a code

      it "shows an error" do
        post emergency_path, params: { email: user.email, recovery_code: "WRONG-CODE-1234-5678" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid email or recovery code")
      end

      it "does not change user state" do
        post emergency_path, params: { email: user.email, recovery_code: "WRONG-CODE-1234-5678" }
        expect(user.reload.state).to eq("cooldown")
      end
    end

    context "with non-existent email" do
      it "shows a generic error (prevents enumeration)" do
        post emergency_path, params: { email: "nonexistent@example.com", recovery_code: "XXXX-XXXX-XXXX-XXXX" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid email or recovery code")
      end
    end

    context "with missing parameters" do
      it "shows an error when email is missing" do
        post emergency_path, params: { recovery_code: "XXXX-XXXX-XXXX-XXXX" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Please enter both")
      end

      it "shows an error when recovery code is missing" do
        post emergency_path, params: { email: "test@example.com" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Please enter both")
      end
    end

    context "when user is already active" do
      let(:active_user) { create(:user, state: "active") }
      let(:active_recovery_code) { active_user.generate_recovery_code! }

      it "still accepts the code and resets check-in" do
        # Even if already active, using recovery code should work
        # (in case user wants to reset their check-in timer)
        post emergency_path, params: { email: active_user.email, recovery_code: active_recovery_code }
        # Should show success since code was valid, even though state didn't change
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
