public with sharing class ProductController { // enforces sharing on PricebookEntry queries so unprofiled products stay hidden
  @AuraEnabled(cacheable=true)
  public static List<GearItem> getFeaturedGear(Integer maxRows) {
    Integer clamped;
    if (maxRows == null || maxRows <= 0) {
      clamped = 4;
    } else if (maxRows > 50) {
      clamped = 50;
    } else {
      clamped = maxRows;
    }

    // WITH USER_MODE so the storefront only surfaces entries the running user can actually read
    List<PricebookEntry> entries = [
      SELECT UnitPrice, Product2.Name, Product2.Family, Product2.Image_Url__c
      FROM PricebookEntry
      WHERE
        IsActive = TRUE
        AND Pricebook2.IsStandard = TRUE
        AND Product2.IsActive = TRUE
      WITH USER_MODE
      ORDER BY Product2.Name ASC
      LIMIT :clamped
    ];

    List<GearItem> result = new List<GearItem>();
    for (PricebookEntry pbe : entries) {
      GearItem item = new GearItem();
      item.name = (pbe.Product2 != null) ? pbe.Product2.Name : null;
      item.family = (pbe.Product2 != null) ? pbe.Product2.Family : null;
      item.price = pbe.UnitPrice;
      item.imageUrl = (pbe.Product2 != null) ? pbe.Product2.Image_Url__c : null;
      result.add(item);
    }
    return result;
  }

  public class GearItem {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String family;
    @AuraEnabled
    public Decimal price;
    @AuraEnabled
    public String imageUrl;
  }
}
