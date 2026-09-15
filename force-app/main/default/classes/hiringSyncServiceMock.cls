@isTest
global class hiringSyncServiceMock implements HttpCalloutMock {
    private Integer statusCode;

    // Constructor to pass dynamic status codes in tests
    global hiringSyncServiceMock(Integer code) {
        this.statusCode = code;
    }

    // Fakes the external system response based on status code
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);

        if (this.statusCode == 200) {
            res.setBody('{"courseId":"104","courseName":".Net","status":"New"}');
        } else if (this.statusCode == 404) {
            res.setBody('{"error":"Not Found"}');
        } else if (this.statusCode == 500) {
            res.setBody('{"error":"Internal Server Error"}');
        }
        return res;
    }
}