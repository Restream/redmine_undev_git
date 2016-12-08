class FetchEvent < ActiveRecord::Base
  belongs_to :repository

  after_commit :cleanup_fetch_events, on: :create

  scope :sorted, -> { order('id desc') }

  def cleanup_fetch_events
    repository.cleanup_fetch_events
  end
end
