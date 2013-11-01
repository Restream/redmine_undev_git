module RedmineUndevGit::Patches
  module CustomFieldValuePatch
    extend ActiveSupport::Concern

    def value_blank?
      value.is_a?(Array) ? value.compact.blank? : value.blank?
    end
  end
end

unless CustomFieldValue.included_modules.include?(RedmineUndevGit::Patches::CustomFieldValuePatch)
  CustomFieldValue.send :include, RedmineUndevGit::Patches::CustomFieldValuePatch
end
