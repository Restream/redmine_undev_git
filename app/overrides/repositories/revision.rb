Deface::Override.new(
    :virtual_path => 'repositories/revision',
    :name => 'branches_for_revision',
    :insert_bottom => 'table.revision-info',
    :text => '<tr><td><%= l(:label_branches) %></td><td><%= changeset_branches(@changeset, 0) %></td></tr>')
