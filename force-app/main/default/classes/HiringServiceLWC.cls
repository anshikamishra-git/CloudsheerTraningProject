public with sharing class HiringServiceLWC {

    /**
     * Annotation Reason: Made cacheable=true so LWC @wire service can fetch and cache interview rounds efficiently.
     */
    @AuraEnabled(cacheable=true)
    public static List<Interview_Round__c> getInterviewRounds(Id jobOpeningId) {
        if (jobOpeningId == null) {
            return new List<Interview_Round__c>();
        }
        return [
            SELECT Id, Name, Completed__c, Due_Date__c, Planned_Hours__c, Job_Opening__c
            FROM Interview_Round__c
            WHERE Job_Opening__c = :jobOpeningId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Annotation Reason: Made cacheable=true because summary calculations are read-only and wired to LWC top summary strip.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> statusBreakdown(Id jobOpeningId) {
        Map<String, Integer> summaryMap = new Map<String, Integer>{
            'Total' => 0,
            'Completed' => 0,
            'Pending' => 0
        };

        if (jobOpeningId == null) {
            return summaryMap;
        }

        List<Interview_Round__c> rounds = [
            SELECT Id, Completed__c, Due_Date__c, Planned_Hours__c
            FROM Interview_Round__c
            WHERE Job_Opening__c = :jobOpeningId
            WITH USER_MODE
        ];

        summaryMap.put('Total', rounds.size());
        for (Interview_Round__c round : rounds) {
            if (round.Completed__c == true) {
                summaryMap.put('Completed', summaryMap.get('Completed') + 1);
            } else {
                summaryMap.put('Pending', summaryMap.get('Pending') + 1);
            }
        }
        return summaryMap;
    }

    /**
     * Annotation Reason: NOT cacheable because write/update operations must always execute directly on the server to maintain data integrity.
     */
    @AuraEnabled
    public static void saveInterviewRounds(List<Interview_Round__c> roundsToUpdate) {
        if (roundsToUpdate != null && !roundsToUpdate.isEmpty()) {
            update as user roundsToUpdate;
        }
    }
}