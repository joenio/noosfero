require File.dirname(__FILE__) + '/../../../../test/test_helper'
require File.dirname(__FILE__) + '/../../controllers/bsc_plugin_myprofile_controller'
require File.dirname(__FILE__) + '/../../../../app/models/uploaded_file'

# Re-raise errors caught by the controller.
class BscPluginMyprofileController; def rescue_action(e) raise e end; end

class BscPluginMyprofileControllerTest < Test::Unit::TestCase

  VALID_CNPJ = '94.132.024/0001-48'

  def setup
    @controller = BscPluginMyprofileController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @bsc = BscPlugin::Bsc.create!({:business_name => 'Sample Bsc', :identifier => 'sample-bsc', :company_name => 'Sample Bsc Ltda.', :cnpj => VALID_CNPJ})
    @admin = create_user('admin').person
    @bsc.add_admin(@admin)
    login_as(@admin.user.login)
    e = Environment.default
    e.enabled_plugins = ['BscPlugin']
    e.save!
  end

  attr_accessor :admin, :bsc

  should 'list enterprises on search' do
    e1 = Enterprise.create!(:name => 'Sample Enterprise 1', :identifier => 'sample-enterprise-1')
    e2 = Enterprise.create!(:name => 'Sample Enterprise 2', :identifier => 'sample-enterprise-2')
    e3 = Enterprise.create!(:name => 'Blo', :identifier => 'blo')
    e4 = Enterprise.create!(:name => 'Sample Enterprise 4', :identifier => 'sample-enterprise-4', :bsc => bsc)
    e5 = Enterprise.create!(:name => 'Sample Enterprise 5', :identifier => 'sample-enterprise-5', :enabled => true)
    BscPlugin::AssociateEnterprise.create!(:requestor => admin, :target => e5, :bsc => bsc)

    get :search_enterprise, :profile => bsc.identifier, :q => 'Sampl'
    
    assert_match /#{e1.name}/, @response.body
    assert_match /#{e2.name}/, @response.body
    assert_no_match /#{e3.name}/, @response.body
    assert_no_match /#{e4.name}/, @response.body
    assert_no_match /#{e5.name}/, @response.body
  end

  should 'save associations' do
    e1 = fast_create(Enterprise, :enabled => false)
    e2 = fast_create(Enterprise, :enabled => false)

    post :save_associations, :profile => bsc.identifier, :q => "#{e1.id},#{e2.id}"
    e1.reload
    e2.reload
    assert_equal e1.bsc, bsc
    assert_equal e2.bsc, bsc

    post :save_associations, :profile => bsc.identifier, :q => "#{e1.id}"
    e1.reload
    e2.reload
    assert_equal e1.bsc, bsc
    assert_not_equal e2.bsc, bsc
  end

  should 'create a task to the enabled enterprise instead of associating it' do
    e = fast_create(Enterprise, :enabled => true)

    assert_difference BscPlugin::AssociateEnterprise, :count, 1 do
      post :save_associations, :profile => bsc.identifier, :q => "#{e.id}"
      bsc.reload
      assert_not_includes bsc.enterprises, e
    end
  end

  should 'transfer enterprises management' do
    p1 = create_user('p1').person
    p2 = create_user('p2').person
    p3 = create_user('p3').person

    role = Profile::Roles.admin(bsc.environment.id)

    bsc.add_admin(p1)
    bsc.add_admin(p2)

    post :transfer_enterprises_management, :profile => bsc.identifier, 'q_'+role.key => "#{p3.id}"

    assert_response :redirect

    assert_not_includes bsc.admins, p1
    assert_not_includes bsc.admins, p2
    assert_includes bsc.admins, p3
  end
end

