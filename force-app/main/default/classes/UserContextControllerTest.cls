@IsTest
public with sharing class UserContextControllerTest {
  @TestSetup
  static void setup() {
    // Need a deterministic profile that exists in every org for runAs
    Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    Long ts = DateTime.now().getTime();
    User named = new User(
      Alias = 'named',
      Email = 'named+' + ts + '@nto.test',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Dakota',
      LastName = 'Named',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = std.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'uctc-named+' + ts + '@nto.test.invalid'
    );
    User blank = new User(
      Alias = 'blank',
      Email = 'blank+' + ts + '@nto.test',
      EmailEncodingKey = 'UTF-8',
      // No FirstName — fallback branch
      LastName = 'Blank',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = std.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'uctc-blank+' + ts + '@nto.test.invalid'
    );
    insert new List<User>{ named, blank };
  }

  @IsTest
  static void testGetCurrentUserFirstName_ReturnsTrimmedName() {
    User u = [
      SELECT Id
      FROM User
      WHERE LastName = 'Named' AND Username LIKE 'uctc-named+%'
      LIMIT 1
    ];
    String result;
    System.runAs(u) {
      result = UserContextController.getCurrentUserFirstName();
    }
    System.assertEquals(
      'Dakota',
      result,
      'must return exact FirstName for a named user'
    );
  }

  @IsTest
  static void testGetCurrentUserFirstName_BlankFallsBackToThere() {
    User u = [
      SELECT Id
      FROM User
      WHERE LastName = 'Blank' AND Username LIKE 'uctc-blank+%'
      LIMIT 1
    ];
    String result;
    System.runAs(u) {
      result = UserContextController.getCurrentUserFirstName();
    }
    System.assertEquals(
      'there',
      result,
      'blank FirstName must fall back to literal "there"'
    );
  }

  @IsTest
  static void testGetCurrentUserFirstName_NeverNull() {
    // Running user (test executor) always has some result; must not be null
    String result = UserContextController.getCurrentUserFirstName();
    System.assertNotEquals(null, result, 'must never return null');
  }
}
