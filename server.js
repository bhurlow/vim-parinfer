var parinfer = require("parinfer");
var http = require("http");

var handler = function(req, res) {

    var body = "";
    req.on('data', function(data) {
        body += data;
    });

    req.on('end', function() {

      if (req.url === "/" ) {
        return res.end('ok')
      }

      else if (req.url === "/indent") {
        console.log('indent happened!')
        var obj = JSON.parse(body);
        var cursor = {
          cursorX: obj.cursor, 
          cursorLine: obj.line
        }
        var executed = parinfer.indentMode(obj.text, cursor)
        console.log('text start')
        console.log(executed.text)
        console.log('text end')
        res.end(executed.text)
      }

      else if (req.url === "/paren") {
        res.end('todo')
      }

    });

};

var server = http.createServer(handler);
server.listen(8088, function() {
  console.log("Server Listening");
});
