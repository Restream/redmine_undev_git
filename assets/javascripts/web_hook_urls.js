$(document).ready(function() {
  $('input.web-hook-url').focus(function () {
    $(this).select().mouseup(function (e) {
      e.preventDefault();
      $(this).unbind("mouseup");
    });
  });
});
