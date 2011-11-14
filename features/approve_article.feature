Feature: approve article
  As a community admin
  I want to approve an article
  In order to share it with other users

  Background:
    Given the following users
      | login      | name        | email                  |
      | joaosilva  | Joao Silva  | joaosilva@example.com  |
      | mariasilva | Maria Silva | mariasilva@example.com |
    And the following articles
      | owner | name | body | homepage |
      | mariasilva | Sample Article | This is an article | true |
      | mariasilva | Dub Wars | This is an article | false |
    And the following communities
      | identifier | name |
      | sample-community | Sample Community |
    And the articles of "Sample Community" are moderated
    And "Maria Silva" is a member of "Sample Community"
    And "Joao Silva" is admin of "Sample Community"

  @selenium
  Scenario: edit an article before approval
    Given I am logged in as "mariasilva"
    And I am on Maria Silva's homepage
    When I follow "Spread" and wait
    And I check "Sample Community"
    And I press "Spread this"
    And I am logged in as "joaosilva"
    And I go to Sample Community's control panel
    And I follow "Process requests" and wait
    And I fill in "Text" with "This is an article edited"
    And I choose "Accept"
    And I press "Apply!"
    And I go to Sample Community's sitemap
    And I follow "Sample Article"
    Then I should see "This is an article edited"

  @selenium
  Scenario: reject an article with explanation
    Given I am logged in as "mariasilva"
    And I go to Maria Silva's cms
    And I follow "Sample Article"
    And I follow "Spread" and wait
    And I check "Sample Community"
    And I press "Spread this"
    And I am logged in as "joaosilva"
    And I go to Sample Community's control panel
    And I follow "Process requests" and wait
    And I choose "Reject"
    And I fill in "Rejection explanation" with "This is not an appropriate article for this community."
    And I press "Apply!"
    When I go to Sample Community's sitemap
    Then I should not see "Sample Article"

  @selenium
  Scenario: reject an article that was removed
    Given I am logged in as "mariasilva"
    And I follow "Dub Wars"
    And I follow "Spread" and wait
    And I check "Sample Community"
    And I press "Spread this"
    And I follow "Delete"
    And I press "Yes, I want."
    When I am logged in as "joaosilva"
    And I go to Sample Community's control panel
    And I follow "Process requests" and wait
    And I choose "Reject"
    And I fill in "Rejection explanation" with "Article was removed."
    And I press "Apply!"
    Then I should see "No pending tasks"
    And I should not see "You have a nil object when you didn't expect it"
