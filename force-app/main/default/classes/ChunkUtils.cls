public with sharing class ChunkUtils {
    
    
    public static List<String> chunkCode(String code, Integer chunkSize) {

        if(String.isBlank(code)){

            return new List<String>();
        }

        List<String> lines = code.split('\n');

        List<String> chunks = new List<String>();

        for(Integer i = 0; i<lines.size(); i += chunkSize){

            Integer endPart = Math.min(i + chunkSize, lines.size());
            List<String> splitPart = new List<String>();


            for(Integer j=i; j<endPart; j++){
                
                splitPart.add(lines[j]);
            }

            chunks.add(String.join(splitPart, '\n'));
        }

        return chunks;
    }
}