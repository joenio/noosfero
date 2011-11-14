class SendEmailPluginAdminController < PluginsController
  append_view_path File.join(File.dirname(__FILE__) + '/../views')

  def index
    @environment = environment
    if request.post?
      if environment.update_attributes(params[:environment])
        session[:notice] = _('Configurations was saved')
        redirect_to :controller => 'plugins'
      else
        session[:notice] = _('Configurations could not be saved')
      end
    end
  end

end
