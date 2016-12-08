Deface::Override.new(
  virtual_path: 'issues/_changesets',
  name:         'branches_for_assoc',
  insert_after: 'erb:contains("link_to_revision")',
  text:         <<INCLUDES
<%= changeset_branches(changeset, RedmineUndevGit.max_branches_in_assoc) %>
<%= link_to_repository(changeset.repository) %>
INCLUDES
)
