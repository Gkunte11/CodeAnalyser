@IsTest

private class ClaudeServiceMockTest{

    private class MockAnthropic implements HttpCalloutMock{

        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            res.setStatusCode(200);
            
            res.setBody('{"id":"msg_1","type":"message","role":"assistant",' + 
            '"content":[{"type":"text","text":"{\"explanation\":\"This class...\",\"line_by_line\":[{\"line\":\"public class X{}\",\"explanation\":\"Declares...\"}]}"}]}');
            return res;
        }

    }

    static testMethod void testExplainApex() {
        Test.setMock(HttpCalloutMock.class, new MockAnthropic());
        String snippet = 'public class HelloWorld { public static void sayHello() { System.debug(\'Hello, World!\'); }};';
        Test.startTest();
        String resp = ClaudeServiceCall.explainCode(snippet);
        Test.stopTest();
        System.assertNotEquals(null, resp);
        System.assert(resp.contains('explanation'));
    }
}