var parinfer = require("parinfer");
var http = require("http");

var handler = function(req, res) {

    var body = "";
    req.on('data', function(data) {
        body += data;
    });

    req.on('end', function() {

      // console.log('raw body', body)
      
      var obj = JSON.parse(body);
      
      var cursor = {
        cursorX: obj.cursor, 
        cursorLine: obj.line
      }
    
      var executed = parinfer.indentMode(obj.text, cursor)
      res.end(executed.text)

      //   if (req.url == "/indent-mode") {
      //       res.end(parinfer.indentMode(obj.text, {"cursorX": obj.cursor,
      //                                              "cursorLine": obj.line}).text + "\n");
      //   }
      //   else if (req.url == "/paren-mode") {
      //       res.end(parinfer.indentMode(obj.text, {"cursorX": obj.cursor,
      //                                              "cursorLine": obj.line}).text + "\n");
      //   }
      //   else if (req.url == "/indent-mode-changed") {
      //       res.end(parinfer.indentMode(body).text + "\n");
      //   }
    });

};

var server = http.createServer(handler);
server.listen(8088, function() {
  console.log("Server Listening");
});

module.exports = function() {
    var server = http.createServer(handler);
    server.listen(8088, function() {
        console.log("Server Listening");
    });
};
