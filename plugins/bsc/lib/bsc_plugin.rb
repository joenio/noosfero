require_dependency 'ext/enterprise'

class BscPlugin < Noosfero::Plugin

  Bsc

  def self.plugin_name
    "BSC"
  end

  def self.plugin_description
    _("Adds the Bsc feature")
  end

  def admin_panel_links
    {:title => _('Create BSC'), :url => {:controller => 'bsc_plugin_environment', :action => 'new'}}
  end

  def control_panel_buttons
    if bsc?(context.profile)
      {:title => _("Manage associated enterprises"), :icon => 'bsc-enterprises', :url => {:controller => 'bsc_plugin_myprofile', :action => 'manage_associated_enterprises'}}
    end
  end

  def create_enterprise_hidden_fields
    'bsc_id'
  end

  def create_enterprise_extra_content
    'similar_enterprises'
  end

  def stylesheet?
    true
  end

  def catalog_list_item_extras(product)
    if bsc?(context.profile)
      if BscPlugin::Bsc.all.any? { |bsc| bsc.members.include?(context.user) }
        lambda {link_to(product.enterprise.short_name, product.enterprise.url, :class => 'bsc-catalog-enterprise-link')}
      else
        lambda {product.enterprise.short_name}
      end
    end
  end

  private
  def bsc?(profile)
    profile.kind_of?(BscPlugin::Bsc)
  end

end
