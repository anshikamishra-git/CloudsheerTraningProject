// Contract:
// Inputs: completeInterviewRounds needs a Set of Ids. Other methods need nothing.
// Outputs: lists of records, or counts.
// Side effects: completeInterviewRounds changes records in the database.
// Sharing mode: with sharing, because this class works on behalf of a
// logged-in user, so it should only see what that user can see.
public with sharing class HiringService {

    // Returns all Job Openings that are Experienced.
    public static List<Job_Opening__c> getExperiencedOpenings() {
        return [SELECT Id, Name, Status__c FROM Job_Opening__c WHERE Status__c = 'Experienced'];
    }

    // Marks the given Interview Rounds as Completed.
    public static void completeInterviewRounds(Set<Id> roundIds) {

        if (roundIds == null || roundIds.isEmpty()) {
            throw new HiringServiceException('Please provide at least one Interview Round Id.');
        }

        List<Interview_Round__c> rounds = [SELECT Id, Planned_Hours__c, Completed__c  FROM Interview_Round__c WHERE Id IN :roundIds];

        for (Interview_Round__c r : rounds) {
            r.Completed__c = true;
        }

        update rounds;
    }

    // Returns how many Job Openings exist for each Status.
    public static List<AggregateResult> statusBreakdown() {
        return [SELECT Status__c, COUNT(Id) totalCount FROM Job_Opening__c GROUP BY Status__c];
    }
}