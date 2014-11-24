class HookBase < ActiveRecord::Base
  self.table_name = 'hooks'

  NOBODY = 'nobody'
  USER = 'user'
  AUTHOR = 'author'
  ASSIGNEE_TYPES = [NOBODY, USER, AUTHOR]

  include Redmine::SafeAttributes

  acts_as_customizable

  serialize :custom_field_values, Hash

  safe_attributes %w{branches keywords status_id done_ratio assigned_to_id custom_field_values}

  belongs_to :status, :class_name => 'IssueStatus'
  belongs_to :assigned_to, :class_name => 'Principal'

  validates :branches, :presence => true
  validates :keywords, :presence => true
  validates :assignee_type, :presence => true, :inclusion => { :in => ASSIGNEE_TYPES }

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
    o_keywords = Array(o_keywords)
    o_branches = Array(o_branches)
    found_keywords = (keywords & o_keywords).any?
    found_branches = any_branch? || (branches & o_branches).any?
    found_keywords && found_branches
  end

  def any_branch?
    branches == %w{*}
  end

  def apply_for_issue(issue, options = {}, &block)
    return unless has_changes_for_issue?(issue)

    updater = options[:user] || User.anonymous
    notes = options[:notes] || "Changed by hook #{id}"

    issue.reload
    issue.init_journal(updater, notes)
    change_issue(issue)

    yield if block_given?

    unless issue.save
      logger.warn("Issue ##{issue.id} could not be updated by hook #{id}: #{issue.errors.full_messages}") if logger
    end
  end

  def assignee(issue = nil)
    case assignee_type
      when USER
        assigned_to
      when AUTHOR
        issue ? issue.author : :field_author
      else
        nil
    end
  end

  private

  def has_changes_for_issue?(issue)
    (status && issue.status != status) ||
        (done_ratio.present? && issue.done_ratio != done_ratio) ||
        (assignee(issue) && issue.assigned_to != assignee(issue)) ||
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
    issue.assigned_to = assignee(issue) if assignee(issue)

    cfvalues = {}
    issue.custom_field_values.each do |cfvalue|
      hook_value = custom_value_for(cfvalue.custom_field)
      cfvalues[cfvalue.custom_field_id] = hook_value.value if hook_value.try(:value).present?
    end
    issue.custom_field_values = cfvalues unless cfvalues.empty?
  end
end
