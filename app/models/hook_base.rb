class HookBase < ActiveRecord::Base
  self.table_name = 'hooks'

  include Redmine::SafeAttributes

  # Each hook has a priority
  acts_as_list :scope => :repository

  safe_attributes %w{branches keywords new_status_id new_done_ratio}

  validates :branches, :presence => true
  validates :keywords, :presence => true

  validate do
    if new_status.nil? && new_done_ratio.nil?
      errors[:base] << I18n.t(:text_hook_cannot_be_empty)
    end
  end

  belongs_to :new_status, :class_name => 'IssueStatus'

  scope :by_position, order("#{table_name}.position")

  def branches
    @branches ||= read_attribute(:branches).to_s.downcase.split(',').map(&:strip)
  end

  def keywords
    @keywords ||= read_attribute(:keywords).to_s.downcase.split(',').map(&:strip)
  end

end
