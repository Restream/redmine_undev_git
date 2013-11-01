module RedmineUndevGit::Patches
  module CustomFieldValuePatch
    extend ActiveSupport::Concern

    def value_blank?
      if value.is_a?(Array)
        value.empty? || value.map(&:blank?).inject(:&)
      else
        value.blank?
      end
    end
  end
end

unless CustomFieldValue.included_modules.include?(RedmineUndevGit::Patches::CustomFieldValuePatch)
  CustomFieldValue.send :include, RedmineUndevGit::Patches::CustomFieldValuePatch
end
