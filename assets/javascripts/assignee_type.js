$(document).ready(function(){
  var showAssigneeSelectOnlyForUser = function() {
    $('select.hook_assigned_to_id').parent().toggle(
      $('select.hook_assignee_type').val() == 'user'
    );
  };
  $('select.hook_assignee_type').on('change', showAssigneeSelectOnlyForUser);
  showAssigneeSelectOnlyForUser();
});
