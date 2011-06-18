require File.dirname(__FILE__) + '/../../../../test/test_helper'
require File.dirname(__FILE__) + '/../../controllers/bsc_plugin_environment_controller'
require File.dirname(__FILE__) + '/../../../../app/models/uploaded_file'

# Re-raise errors caught by the controller.
class BscPluginEnvironmentController; def rescue_action(e) raise e end; end

class BscPluginEnvironmentControllerTest < Test::Unit::TestCase

  VALID_CNPJ = '94.132.024/0001-48'

  def setup
    @controller = BscPluginEnvironmentController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    user_login = create_admin_user(Environment.default)
    login_as(user_login)
    @admin = User[user_login].person
    e = Environment.default
    e.enabled_plugins = ['BscPlugin']
    e.save!
  end

  attr_accessor :admin

  should 'create a new bsc' do
    assert_difference BscPlugin::Bsc, :count, 1 do
      post :new, :profile_data => {:business_name => 'Sample Bsc', :identifier => 'sample-bsc', :company_name => 'Sample Bsc Ltda.', :cnpj => VALID_CNPJ}
    end

    assert_redirected_to :controller => 'admin_panel'
  end

  should 'not create an invalid bsc' do
    assert_difference BscPlugin::Bsc, :count, 0 do
      post :new, :profile_data => {:business_name => 'Sample Bsc', :identifier => 'sample-bsc', :company_name => 'Sample Bsc Ltda.', :cnpj => '29837492304'}
    end

    assert_response 200
  end

  should 'set the current user as the bsc admin' do
    name = 'Sample Bsc'
    post :new, :profile_data => {:business_name => name, :identifier => 'sample-bsc', :company_name => 'Sample Bsc Ltda.', :cnpj => VALID_CNPJ}
    bsc = BscPlugin::Bsc.find_by_name(name)
    assert_includes bsc.admins, admin
  end

end
