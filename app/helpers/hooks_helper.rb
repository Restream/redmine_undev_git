module HooksHelper
  # Return custom field label tag (required ignored!)
  def hook_custom_field_label_tag(name, custom_value, options={})
    content_tag 'label', h(custom_value.custom_field.name),
      for: "#{name}_custom_field_values_#{custom_value.custom_field.id}"
  end

  # Return custom field html tag corresponding to its format (required ignored!)
  def hook_custom_field_value_tag(name, custom_value)
    custom_field = custom_value.custom_field
    field_name   = "#{name}[custom_field_values][#{custom_field.id}]"
    field_name << '[]' if custom_field.multiple?
    field_id = "#{name}_custom_field_values_#{custom_field.id}"

    tag_options = { id: field_id, class: "#{custom_field.field_format}_cf" }

    field_format = Redmine::CustomFieldFormat.find_by_name(custom_field.field_format)
    case field_format.try(:edit_as)
      when 'date'
        text_field_tag(field_name, custom_value.value, tag_options.merge(size: 10)) +
          calendar_for(field_id)
      when 'text'
        text_area_tag(field_name, custom_value.value, tag_options.merge(rows: 3))
      when 'bool'
        hidden_field_tag(field_name, '0') + check_box_tag(field_name, '1', custom_value.true?, tag_options)
      when 'list'
        blank_option = ''.html_safe
        unless custom_field.multiple?
          blank_option = content_tag('option')
        end
        s = select_tag(field_name,
          blank_option + options_for_select(
            custom_field.possible_values_options(custom_value.customized),
            custom_value.value),
          tag_options.merge(multiple: custom_field.multiple?))
        if custom_field.multiple?
          s << hidden_field_tag(field_name, '')
        end
        s
      else
        text_field_tag(field_name, custom_value.value, tag_options)
    end
  end

  # Return custom field tag with its label tag (required ignored!)
  def hook_custom_field_value_tag_with_label(name, custom_value, options={})
    hook_custom_field_label_tag(name, custom_value, options) +
      hook_custom_field_value_tag(name, custom_value)
  end

  def hook_column_content(column_name, hook)
    value = hook.send column_name
    if value.is_a?(Array)
      value.collect { |v| hook_column_value(column_name, v) }.compact.join(', ').html_safe
    else
      hook_column_value(column_name, value)
    end
  end

  def hook_column_value(column_name, value)
    case value.class.name
      when 'Symbol'
        l(value)
      when 'String'
        h(value)
      when 'Time'
        format_time(value)
      when 'Date'
        format_date(value)
      when 'Fixnum'
        if column_name == :done_ratio
          "#{value.to_s}%"
        else
          value.to_s
        end
      when 'Float'
        sprintf '%.2f', value
      when 'User'
        link_to_user value
      when 'Project'
        link_to_project value
      when 'Version'
        link_to(h(value), controller: 'versions', action: 'show', id: value)
      when 'TrueClass'
        l(:general_text_Yes)
      when 'FalseClass'
        l(:general_text_No)
      when 'IssueStatus'
        h(value.name)
      else
        h(value)
    end
  end

end
