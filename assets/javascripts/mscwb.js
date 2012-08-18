(function() {
  var token = __mswbq_token;
  var i = new Image();

  var pattern=/(.+:\/\/)?([^\/]+)(\/.*)*/i;
  var parts = pattern.exec(document.getElementById('__mswb').src);
  var protocol = parts[1];
  var server = parts[2];

  i.src = protocol + server + '/api/conversions/new?token=' + token;
})();
