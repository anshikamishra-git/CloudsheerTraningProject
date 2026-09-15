public class HiringServiceTestData {
    // This class creates test data. Every test will call this instead of
// making its own records by hand.


    // Creates a few Job Openings with different statuses,
    // and gives each one 2 Interview Rounds.
    public static void createTestData() {

        List<Job_Opening__c> openings = new List<Job_Opening__c>();
        openings.add(new Job_Opening__c(Name = 'Cloud Engineer', Status__c = 'Intern'));
        openings.add(new Job_Opening__c(Name = 'Project Manager', Status__c = 'Fresher'));
        openings.add(new Job_Opening__c(Name = 'Automation Engineer', Status__c = 'Developer'));
        openings.add(new Job_Opening__c(Name = 'Technical Support', Status__c = 'Experienced'));

        insert openings;

        List<Interview_Round__c> rounds = new List<Interview_Round__c>();
        for (Job_Opening__c o : openings) {
            rounds.add(new Interview_Round__c(Job_Opening__c = o.Id, Completed__c  = False, Planned_Hours__c = 2));
            rounds.add(new Interview_Round__c(Job_Opening__c = o.Id, Completed__c  = False, Planned_Hours__c = 2));
        }

        insert rounds;
    }
}