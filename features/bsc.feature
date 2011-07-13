Feature: bsc

  Background:
    Given the folllowing "bsc" from "bsc_plugin"
      | nickname | identifier | company_name  | cnpj               |
      | Bsc Test | bsc-test   | Bsc Test Ltda | 94.132.024/0001-48 |
    And the following user
      | login | name        |
      | mario | Mario Souto |
    And "Mario Souto" is admin of "Bsc Test"
    And I am logged in as "mario"
    And "Bsc" plugin is enabled
    And I am on Bsc Test's control panel

  Scenario: do not display "add new product" button
    When I follow "Manage Products and Services"
    Then I should not see "New product or service"

