// Creates two NTO Experience Cloud portal users for the interview demo.
// Profile: Customer Community Plus Login User (PowerCustomerSuccess)
// Run: sf apex run --file scripts/apex/create_portal_users.apex --target-org Demo-Org

String profileId = '00eNS00000KZ98hYAD'; // Customer Community Plus Login User

List<User> toInsert = new List<User>{
    new User(
        ProfileId         = profileId,
        ContactId         = '003NS00002B6LxfYAF',  // Avery Stone – NTO Hero Account
        FirstName         = 'Avery',
        LastName          = 'Stone',
        Email             = 'avery.stone@nto-demo.com',
        Username          = 'avery.stone@nto-portal.demo',
        Alias             = 'astone',
        CommunityNickname = 'avery.stone',
        TimeZoneSidKey    = 'Asia/Manila',
        LocaleSidKey      = 'en_US',
        EmailEncodingKey  = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        IsActive          = true
    ),
    new User(
        ProfileId         = profileId,
        ContactId         = '003NS00002B6LxeYAF',  // Drew Customer 50 – NTO Customer 25
        FirstName         = 'Drew',
        LastName          = 'Customer 50',
        Email             = 'customer50@nto-demo.com',
        Username          = 'customer50@nto-portal.demo',
        Alias             = 'dcust50',
        CommunityNickname = 'customer50',
        TimeZoneSidKey    = 'Asia/Manila',
        LocaleSidKey      = 'en_US',
        EmailEncodingKey  = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        IsActive          = true
    )
};

try {
    insert toInsert;
    for (User u : toInsert) {
        System.debug('CREATED: ' + u.Username + ' | Id=' + u.Id);
    }
} catch (DmlException e) {
    System.debug('ERROR: ' + e.getMessage());
}
