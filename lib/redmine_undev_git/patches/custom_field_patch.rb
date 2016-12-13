require_dependency 'custom_field'

module RedmineUndevGit
  module Patches
    module CustomFieldPatch

      def possible_values_options(obj=nil)
        if obj.is_a?(GlobalHook) && %w(user version).include?(field_format)
          case field_format
            when 'user'
              User.active.sort.collect { |u| [u.to_s, u.id.to_s] }
            when 'version'
              Version.visible.sort.collect { |u| [u.to_s, u.id.to_s] }
          end
        else
          super
        end
      end
    end
  end
end
