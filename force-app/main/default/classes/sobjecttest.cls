public class sobjecttest {
    public static void datainsert(){//void is a kind of Returntype which indicates that it does not return 
          Account acc = new Account();
          acc.Name = 'HCL Tech';
          acc.Rating = 'Cold';
          acc.Type = 'Customer-Direct';
          
          insert acc;
    }
    public static id parameterinsert(string Name, string Rating, string Type){
          Account acc = new Account();
          acc.Name = Name;
          acc.Rating = Rating;
          acc.Type = Type;
          
          insert acc;
        return acc.Id; //an id of the created account will get returned  using this .
    }
    
    //inserting related contact record
    public static void insertcontact(){
        Id accId;
        accId = parameterinsert('abcd', 'Cold', 'other');
        Contact cons = new Contact(FirstName = 'Khushi', Lastname = 'Twari');
        cons.accountId = accId;  //accountId is lookup to account
        insert cons;
    }
}