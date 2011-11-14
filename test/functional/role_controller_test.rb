require File.dirname(__FILE__) + '/../test_helper'
require 'role_controller'

# Re-raise errors caught by the controller.
class RoleController; def rescue_action(e) raise e end; end

class RoleControllerTest < Test::Unit::TestCase
  all_fixtures

  def setup
    @controller = RoleController.new
    @request    = ActionController::TestRequest.new
    @request.stubs(:ssl?).returns(true)
    @response   = ActionController::TestResponse.new
    @role = Role.find(:first)
    login_as(:ze)
  end

  def test_local_files_reference
    assert_local_files_reference
  end
  
  def test_valid_xhtml
    assert_valid_xhtml
  end
  
  def test_index_should_get_roles
    get 'index'
    assert_response :success
    assert assigns(:roles)
  end

  def test_show_should_fetch_role
    get 'show', :id => @role.id
    assert_response :success
    assert_template 'show'
    assert assigns(:role)
    assert_equal @role.id, assigns(:role).id 
  end

  def test_can_edit
    get 'edit', :id => @role.id
    assert_not_nil assigns(:role)
    assert_equal @role.id, assigns(:role).id 
  end

  def test_should_update_to_valid_parameters
    Role.any_instance.stubs(:valid?).returns(true)
    post 'update', :id => @role.id
    assert_response :redirect
    assert_not_nil assigns(:role)
    assert_nil session[:notice]
  end
  
  def test_should_not_update_to_invalid_paramters
    Role.any_instance.stubs(:valid?).returns(false)
    post 'update', :id => @role.id
    assert_response :success
    assert_not_nil assigns(:role)
    assert_not_nil session[:notice]
  end

  should 'not crash when editing role with no permissions' do
    role = Role.create!(:name => 'test_role', :environment => Environment.default)

    assert_nothing_raised do
      get :edit, :id => role.id
    end
  end
end
