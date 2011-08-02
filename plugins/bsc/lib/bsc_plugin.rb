require_dependency 'ext/enterprise'
require_dependency 'ext/product'

class BscPlugin < Noosfero::Plugin

  Bsc

  def self.plugin_name
    "BSC"
  end

  def self.plugin_description
    _("Adds the Bsc feature")
  end

  def admin_panel_links
    {:title => _('Create Bsc'), :url => {:controller => 'bsc_plugin_environment', :action => 'new'}}
  end

  def control_panel_buttons
    buttons = []
    buttons << {:title => _("Manage associated enterprises"), :icon => 'bsc-enterprises', :url => {:controller => 'bsc_plugin_myprofile', :action => 'manage_associated_enterprises'}} if bsc?(context.profile)
    buttons << {:title => _('Transfer ownership'), :icon => '', :url => {:controller => 'bsc_plugin_myprofile', :action => 'transfer_ownership'}} if context.profile.enterprise?
    buttons
  end

  def manage_members_extra_buttons
    {:title => _('Transfer ownership'), :icon => '', :url => {:controller => 'bsc_plugin_myprofile', :action => 'transfer_enterprises_management'}} if context.profile.enterprise?
  end

  def create_enterprise_hidden_fields
    ['bsc_id', 'enabled', 'validated']
  end

  def create_enterprise_extra_content
    'similar_enterprises'
  end

  def stylesheet?
    true
  end

  def catalog_list_item_extras(product)
    if bsc?(context.profile)
      enterprise = product.enterprise
      if is_member_of_any_bsc?(context.user)
        lambda {link_to(enterprise.short_name, enterprise.url, :class => 'bsc-catalog-enterprise-link')}
      else
        lambda {enterprise.short_name}
      end
    end
  end

  def profile_controller_filters
    if profile
      special_enterprise = !profile.validated && profile.bsc
      is_member_of_any_bsc = is_member_of_any_bsc?(context.user)
      block = lambda {
        render_access_denied if special_enterprise && !is_member_of_any_bsc
      }

      [{ :type => 'before_filter', :method_name => 'bsc_access', :block => block }]
    else
      []
    end
  end

  def content_viewer_controller_filters
    if profile
      special_enterprise = !profile.validated && profile.bsc
      is_member_of_any_bsc = is_member_of_any_bsc?(context.user)
      block = lambda {
        render_access_denied if special_enterprise && !is_member_of_any_bsc
      }

      [{ :type => 'before_filter', :method_name => 'bsc_access', :block => block }]
    else
      []
    end
  end

  def asset_product_properties(product)
    properties = []
    properties << { :name => _('Bsc'), :content => lambda { link_to(product.bsc.name, product.bsc.url) } } if product.bsc
    if product.enterprise.validated || is_member_of_any_bsc?(context.user)
      content = lambda { link_to_homepage(product.enterprise.name, product.enterprise.identifier) }
    else
      content = lambda { product.enterprise.name }
    end
    properties << { :name => _('Supplier'), :content => content }
  end

  private

  def bsc?(profile)
    profile.kind_of?(BscPlugin::Bsc)
  end

  def is_member_of_any_bsc?(user)
    BscPlugin::Bsc.all.any? { |bsc| bsc.members.include?(user) }
  end

  def profile
    context.environment.profiles.find_by_identifier(context.params[:profile])
  end

end
