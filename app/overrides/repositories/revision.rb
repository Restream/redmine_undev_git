Deface::Override.new(
    :virtual_path => 'repositories/revision',
    :name => 'revision_rebased_to',
    :insert_after => 'h2 code:contains(\'format_revision(@changeset)\')',
    :text => <<-REBASE_INFO

<% if @changeset.rebased_to %>

  <%=
    link_to_revision_wb(@changeset.rebased_to, @repository) do
      image_tag('tag_blue_delete.png',
                :plugin => 'redmine_undev_git',
                :title => l(:text_commit_was_rebased_to,
                            :rebased_to => format_revision(@changeset.rebased_to))) +
      content_tag(:em, :class => 'rebased-to') do
        l(:text_commit_was_rebased_to, :rebased_to => format_revision(@changeset.rebased_to))
      end
    end
  %>

<% elsif @changeset.rebased_from %>

  <%=
    link_to_revision_wb(@changeset.rebased_from, @repository) do
      image_tag('tag_blue_add.png',
                :plugin => 'redmine_undev_git',
                :title => l(:text_commit_was_rebased_from,
                            :rebased_from => format_revision(@changeset.rebased_from))) +
      content_tag(:em, :class => 'rebased-from') do
        l(:text_commit_was_rebased_from, :rebased_from => format_revision(@changeset.rebased_from))
      end
    end
  %>

<% end %>

REBASE_INFO
)

Deface::Override.new(
    :virtual_path => 'repositories/revision',
    :name => 'branches_for_revision',
    :insert_bottom => 'table.revision-info',
    :text => '<tr><td><%= l(:label_branches) %></td><td><%= changeset_branches(@changeset, 0) %></td></tr>')
