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
    @branches ||= read_attribute(:branches).to_s.split_by_comma
  end

  def keywords
    @keywords ||= read_attribute(:keywords).to_s.split_by_comma
  end

  def applied_for?(o_keywords, o_branches)
    o_keywords = o_keywords.join(',') if o_keywords.respond_to?(:join)
    o_branches = o_branches.join(',') if o_branches.respond_to?(:join)
    found_keywords = (keywords.to_s.split_by_comma & o_keywords.to_s.split_by_comma).any?
    found_branches = any_branch? || (branches.to_s.split_by_comma & o_branches.to_s.split_by_comma).any?
    found_keywords && found_branches
  end

  def any_branch?
    branches.strip == '*'
  end

  def apply_for_issue_by_changeset(issue, changeset)

    # the issue may have been updated
    issue.reload

    # do not update if there are no actual changes
    return if (new_status.nil? || issue.status == new_status) &&
              (new_done_ratio.nil? || issue.done_ratio == new_done_ratio)

    issue.init_journal(
        changeset.user || User.anonymous,
        ll(Setting.default_language, :text_changed_by_changeset_hook, text_tag(issue.project))
    )
    issue.status = new_status if new_status
    issue.done_ratio = done_ratio if new_done_ratio
    Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
                            { :changeset => changeset, :issue => issue })
    unless issue.save
      logger.warn("Issue ##{issue.id} could not be saved by changeset #{changeset.id}: #{issue.errors.full_messages}") if logger
    end
    issue
  end
end
