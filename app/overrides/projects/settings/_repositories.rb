Deface::Override.new(
  virtual_path: 'projects/settings/_repositories',
  name:         'fetch_events_status_th',
  insert_after: 'erb:contains("l(:label_repository)")',
  text:         '</th><th><%= l(:label_fetch_status) %>')

Deface::Override.new(
  virtual_path: 'projects/settings/_repositories',
  name:         'fetch_events_status_td',
  insert_after: 'erb:contains("h repository.url")',
  text:         '</td><td><%= status_image_tag(repository) %>')
