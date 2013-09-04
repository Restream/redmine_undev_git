class HookBase < ActiveRecord::Base
  self.table_name = 'hooks'

  include Redmine::SafeAttributes

  acts_as_customizable

  serialize :custom_field_values, Hash

  safe_attributes %w{branches keywords status_id done_ratio assigned_to_id custom_field_values}

  belongs_to :status, :class_name => 'IssueStatus'
  belongs_to :assigned_to, :class_name => 'Principal'

  validates :branches, :presence => true
  validates :keywords, :presence => true

  scope :by_position, order("#{table_name}.position")

  def available_custom_fields
    CustomField.where('type = ?', 'IssueCustomField').order('position')
  end

  # disable validation for custom fields
  def validate_custom_field_values
    true
  end

  def branches
    @branches ||= read_attribute(:branches).to_s.split_by_comma
  end

  def keywords
    @keywords ||= read_attribute(:keywords).to_s.split_by_comma
  end

  def applied_for?(o_keywords, o_branches)
    found_keywords = (keywords & o_keywords).any?
    found_branches = any_branch? || (branches & o_branches).any?
    found_keywords && found_branches
  end

  def any_branch?
    branches == %w{*}
  end

  def apply_for_issue_by_changeset(issue, changeset)

    # the issue may have been updated
    issue.reload

    # do not update if there are no actual changes
    return if (status.nil? || issue.status == status) &&
              (done_ratio.nil? || issue.done_ratio == done_ratio)

    issue.init_journal(
        changeset.user || User.anonymous,
        ll(Setting.default_language, :text_changed_by_changeset_hook, changeset.full_text_tag(issue.project))
    )
    issue.status = status if status
    issue.done_ratio = done_ratio if done_ratio
    Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
                            { :changeset => changeset, :issue => issue, :hook => self })
    unless issue.save
      logger.warn("Issue ##{issue.id} could not be saved by changeset #{changeset.id}: #{issue.errors.full_messages}") if logger
    end
    issue
  end
end
