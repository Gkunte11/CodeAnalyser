@IsTest

private class AnthropicCallMockTest{

    private class MockAnthropic implements HttpCalloutMock{

        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            res.setStatusCode(200);
            
            res.setBody('{"id":"msg_1","type":"message","role":"assistant",' + 
            '"content":[{"type":"text","text":"{\"explanation\":\"This class...\",\"line_by_line\":[{\"line\":\"public class X{}\",\"explanation\":\"Declares...\"}]}"}]}');
            return r;
        }

    }

    static testMethod void testExplainApex() {
        Test.setMock(HttpCalloutMock.class, new MockClaude());
        String snippet = 'public class HelloWorld { public static void sayHello() { System.debug(\'Hello, World!\'); }};'
        Test.startTest();
        String resp = ClaudeService.explainApex(snippet);
        Test.stopTest();
        System.assertNotEquals(null, resp);
        System.assert(resp.contains('explanation'));
    }
}