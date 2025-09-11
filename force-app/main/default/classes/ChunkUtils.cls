public with sharing class ChunkUtils {
    
    
    public static List<String> ChunkUtils(String code, Integer chunkSize) {

        if(String.isBlank(code)){

            return new List<String>();
        }

        List<String> lines = code.split('\n');

        List<String> chunks = new List<String>();

        for(Integer i = 0; i<lines.size(); i += chunkSize){

            List<String> splitPart = lines.subList(i, Math.min(i + chunkSize, lines.size()));
            chunks.add(String.join(splitPart, '\n'));
        }

        return chunks;
    }
}