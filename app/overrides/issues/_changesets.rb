Deface::Override.new(
    :virtual_path => 'issues/_changesets',
    :name => 'branches_for_assoc',
    :insert_after => 'code:contains("link_to_revision")',
    :text => <<INCLUDES
<%= changeset_branches(changeset, Setting.plugin_redmine_undev_git[:max_branches_in_assoc].to_i) %>
<%= link_to_repository(changeset.repository) %>
INCLUDES
)
