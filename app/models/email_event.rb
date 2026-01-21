# frozen_string_literal: true

class EmailEvent < ApplicationRecord
  PROVIDERS = %w[generic sendgrid postmark mailgun ses].freeze
  EVENT_TYPES = %w[delivered bounced complained opened clicked deferred].freeze

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }

  scope :recent, -> { order(created_at: :desc) }
  scope :bounces, -> { where(event_type: "bounced") }
  scope :complaints, -> { where(event_type: "complained") }
end
