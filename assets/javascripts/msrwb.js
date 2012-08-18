(function() {
  var token = __mswbq_token;
  var source_url = encodeURIComponent(document.referrer);
  var i = new Image();

  var pattern=/(.+:\/\/)?([^\/]+)(\/.*)*/i;
  var parts = pattern.exec(document.getElementById('__mswb').src);
  var protocol = parts[1];
  var server = parts[2];

  i.src = protocol + server + '/api/referrals/new?token=' + token + '&source_url=' + source_url;
})();
