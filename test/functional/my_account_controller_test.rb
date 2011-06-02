require File.dirname(__FILE__) + '/../test_helper'
require 'my_account_controller'

# Re-raise errors caught by the controller.
class MyAccountController; def rescue_action(e) raise e end; end

class MyAccountControllerTest < Test::Unit::TestCase

  def setup
    @controller = MyAccountController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @profile = create_user('test_profile').person
    login_as(@profile.identifier)
  end

  attr_reader :profile

  def test_should_display_change_password_screen
    get :change_password, :profile => profile.identifier
    assert_response :success
    assert_template 'change_password'
    assert_tag :tag => 'input', :attributes => { :name => 'current_password' }
    assert_tag :tag => 'input', :attributes => { :name => 'new_password' }
    assert_tag :tag => 'input', :attributes => { :name => 'new_password_confirmation' }
  end

  def test_should_be_able_to_change_password
    post :change_password, :current_password => profile.name.underscore, :new_password => 'blabla', :new_password_confirmation => 'blabla', :profile => profile.identifier
    assert_response :redirect
    assert_redirected_to :controller => 'profile_editor', :profile => profile.identifier
    assert User.find_by_login(profile.identifier).authenticated?('blabla')
  end

  should 'input current password erroneously to change password' do
    post :change_password, :current_password => 'wrong', :new_password => 'blabla', :new_password_confirmation => 'blabla', :profile => profile.identifier
    assert_response :success
    assert_template 'change_password'
    assert ! User.find_by_login(profile.identifier).authenticated?('blabla')
  end
end
