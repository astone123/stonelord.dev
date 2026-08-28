// CloudFront Function (runtime cloudfront-js-2.0), attached by
// apply-cloudfront-fixes.sh to the www distribution's default cache behavior
// on viewer-request: 301 every www.stonelord.dev request to the apex host,
// preserving path and query string.
function handler(event) {
  var request = event.request;
  var params = [];
  for (var key in request.querystring) {
    var entry = request.querystring[key];
    if (entry.multiValue) {
      entry.multiValue.forEach(function (item) {
        params.push(key + '=' + item.value);
      });
    } else if (entry.value === '') {
      params.push(key);
    } else {
      params.push(key + '=' + entry.value);
    }
  }
  var qs = params.length ? '?' + params.join('&') : '';
  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: {
      location: { value: 'https://stonelord.dev' + request.uri + qs }
    }
  };
}
