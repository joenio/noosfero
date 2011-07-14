Feature: bsc

  Background:
    Given the folllowing "bsc" from "bsc_plugin"
      | business_name | identifier | company_name  | cnpj               |
      | Bsc Test      | bsc-test   | Bsc Test Ltda | 94.132.024/0001-48 |
    And the following user
      | login | name        |
      | mario | Mario Souto |
    And "Mario Souto" is admin of "Bsc Test"
    And I am logged in as "mario"
    And "Bsc" plugin is enabled
    And feature "disable_products_for_enterprises" is disabled on environment
    And I am on Bsc Test's control panel

  Scenario: do not display "add new product" button
    When I follow "Manage Products and Services"
    Then I should not see "New product or service"

  Scenario: display bsc's enterprises' products name on the bsc catalog
    Given the following enterprise
      | identifier        | name              |
      | sample-enterprise | Sample Enterprise |
    And the following product_category
      | name |
      | bike |
    And the following products
      | owner             | category  | name          |
      | sample-enterprise | bike      | Master Bike   |
    And "Sample Enterprise" is associated with "Bsc Test"
    When I go to Bsc Test's products page
    Then I should see "Master Bike"
    And I should see "Sample Enterprise"

  Scenario: display enterprise name linked only if person is member of any Bsc
    Given the following enterprise
      | identifier        | name              |
      | sample-enterprise | Sample Enterprise |
    And the following product_category
      | name |
      | bike |
    And the following products
      | owner             | category  | name          |
      | sample-enterprise | bike      | Master Bike   |
    And "Sample Enterprise" is associated with "Bsc Test"
    And the folllowing "bsc" from "bsc_plugin"
      | business_name | identifier    | company_name          | cnpj               |
      | Another Bsc   | another-bsc   | Another Bsc Test Ltda | 07.970.746/0001-77 |
    And the following user
      | login | name        |
      | pedro | Pedro Souto |
      | maria | Maria Souto |
    And pedro is member of another-bsc
    But I am logged in as "maria"
    When I go to Bsc Test's products page
    Then I should see "Sample Enterprise"
#TODO -> test that it's not a link
    But I am logged in as "pedro"
    When I go to Bsc Test's products page
    Then I should see "Sample Enterprise"
    And I should see "Sample Enterprise" within "a.bsc-catalog-enterprise-link"
