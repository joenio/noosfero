class MyAccountController < MyProfileController
  protect 'edit_profile', :profile

  def change_password
    if request.post?
      begin
        @user = Person[params[:profile]].user
        @user.change_password!(params[:current_password],
                               params[:new_password],
                               params[:new_password_confirmation])
        session[:notice] = _('Your password has been changed successfully!')
        redirect_to :controller => 'profile_editor', :profile => params[:profile]
      rescue User::IncorrectPassword => e
        session[:notice] = _('The supplied current password is incorrect.')
        render :action => 'change_password'
      end
    else
      render :action => 'change_password'
    end
  end
end
