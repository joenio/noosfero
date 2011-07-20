class BscPluginEnvironmentController < AdminController

  def new
    @bsc = BscPlugin::Bsc.new(params[:profile_data])
    if request.post? && @bsc.valid?
      @bsc.user = current_user
      @bsc.save!
      @bsc.add_admin(user)
      session[:notice] = _('Your Bsc was created.')
      redirect_to :controller => 'admin_panel', :action => 'index'
    end
  end

end

