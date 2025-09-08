public with sharing class ClaudeFileHandler {
    @AuraEnabled
    public static String getFileContent(Id contentDocumentId) {
        ContentVersion cv = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
            ORDER BY VersionNumber DESC 
            LIMIT 1
        ];
        return cv.VersionData.toString();
    }
}