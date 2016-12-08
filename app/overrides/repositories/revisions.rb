Deface::Override.new(
  virtual_path:  'repositories/_revisions',
  name:          'rebase_info_th',
  insert_before: 'table.list.changesets th:contains(\'l(:label_date)\')',
  text:          '<th></th>')

Deface::Override.new(
  virtual_path:  'repositories/_revisions',
  name:          'rebase_info_td',
  insert_before: 'table.list.changesets td.committed_on',
  text:          <<-REBASE_INFO_TD

<% if changeset.rebased_to %>

  <td class="rebase-info rebased-to"><%=
    link_to_revision_wb(changeset.rebased_to, @repository) do
      image_tag('tag_blue_delete.png',
                plugin: 'redmine_undev_git',
                title: l(:text_commit_was_rebased_to,
                            rebased_to: format_revision(changeset.rebased_to)))
    end
  %></td>

<% elsif changeset.rebased_from %>

  <td class="rebase-info rebased-from"><%=
    link_to_revision_wb(changeset.rebased_from, @repository) do
      image_tag('tag_blue_add.png',
                plugin: 'redmine_undev_git',
                title: l(:text_commit_was_rebased_from,
                            rebased_from: format_revision(changeset.rebased_from)))
    end
  %></td>

<% else %>

  <td class="rebase-info"></td>

<% end %>

REBASE_INFO_TD
)
