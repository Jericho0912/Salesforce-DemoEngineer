public with sharing class UserContextController { // enforces sharing even though we only ever read the running user's own row
  @AuraEnabled(cacheable=true)
  public static String getCurrentUserFirstName() {
    Id currentUserId = UserInfo.getUserId();
    String firstName = null;
    // WITH USER_MODE so FLS on User.FirstName is honored consistently with other controllers
    for (User u : [
      SELECT FirstName
      FROM User
      WHERE Id = :currentUserId
      WITH USER_MODE
      LIMIT 1
    ]) {
      firstName = u.FirstName;
    }

    if (String.isBlank(firstName)) {
      return 'there';
    }
    return firstName.trim();
  }
}
