Deface::Override.new(
    virtual_path: 'issues/show',
    name: 'related_remote_repo_revisions',
    replace: 'code:contains("if @changesets.present?")',
    closing_selector: 'code:contains("end")',
    text: <<INCLUDES
<% if @changesets.present? || remote_revisions.present? %>
<div id="issue-changesets">
  <% if @changesets.present? %>
  <h3><%=l(:label_associated_revisions)%></h3>
  <%= render partial: 'changesets', locals: { changesets: @changesets} %>
  <% end %>
  <% if remote_revisions.present? %>
  <h3><%=l(:label_associated_remote_revisions)%></h3>
  <%= render partial: 'remote_revisions', locals: { remote_revisions: remote_revisions} %>
  <% end %>
</div>
<% end %>
INCLUDES
)
