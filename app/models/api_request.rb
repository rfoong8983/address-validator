class ApiRequest < ApplicationRecord
  include AASM

  aasm do
    state :created, initial: true
    state :requesting
    state :failed
    state :success

    event :start do
      transitions from: :created, to: :requesting
    end

    event :complete do
      transitions from: :requesting, to: :success
    end

    event :fail do
      transitions from: [:requesting, :created], to: :failed
    end
  end
end
