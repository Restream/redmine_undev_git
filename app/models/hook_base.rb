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

    return unless has_changes_for_issue?(issue)

    issue.init_journal(
        changeset.user || User.anonymous,
        ll(Setting.default_language, :text_changed_by_changeset_hook, changeset.full_text_tag(issue.project))
    )

    change_issue(issue)

    Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
                            { :changeset => changeset, :issue => issue, :hook => self })
    unless issue.save
      logger.warn("Issue ##{issue.id} could not be saved by changeset #{changeset.id}: #{issue.errors.full_messages}") if logger
    end
    issue
  end

  private

  def has_changes_for_issue?(issue)
    (status && issue.status != status) ||
        (done_ratio.present? && issue.done_ratio != done_ratio) ||
        (assigned_to && issue.assigned_to != assigned_to) ||
        has_custom_field_changes_for_issue?(issue)
  end

  def has_custom_field_changes_for_issue?(issue)
    issue.custom_field_values.inject(false) do |has_changes, cfvalue|
      hook_value = custom_value_for(cfvalue.custom_field)
      has_changes || (hook_value.try(:value).present? && cfvalue.value != hook_value.value)
    end
  end

  def change_issue(issue)
    issue.status = status if status
    issue.done_ratio = done_ratio if done_ratio.present?
    issue.assigned_to = assigned_to if assigned_to

    cfvalues = {}
    issue.custom_field_values.each do |cfvalue|
      hook_value = custom_value_for(cfvalue.custom_field)
      cfvalues[cfvalue.custom_field_id] = hook_value.value if hook_value.value.present?
    end
    issue.custom_field_values = cfvalues unless cfvalues.empty?
  end
end
