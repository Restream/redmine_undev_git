require_dependency 'custom_field_value'

module RedmineUndevGit
  module Patches
    module CustomFieldValuePatch

      def value_blank?
        if value.is_a?(Array)
          value.empty? || value.map(&:blank?).inject(:&)
        else
          value.blank?
        end
      end
    end
  end
end
