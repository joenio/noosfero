module NoosferoHttpCaching

  def self.included(c)
    c.send(:after_filter, :noosfero_set_cache)
    c.send(:before_filter, :noosfero_session_check_before)
    c.send(:after_filter, :noosfero_session_check_after)
  end

  def noosfero_set_cache
    return if logged_in?
    n = nil
    if profile
      unless request.path =~ /^\/myprofile/
        n = environment.profile_cache_in_minutes
      end
    else
      if request.path == '/'
        n = environment.home_cache_in_minutes
      else
        if params[:controller] != 'account' && !request.xhr? && request.path !~ /^\/admin/
          n = environment.general_cache_in_minutes
        end
      end
    end
    if n
      expires_in n.minutes, :private => false, :public => true
    end
  end

  def noosfero_session_check_before
    return if params[:controller] == 'account' || request.xhr?
    headers["X-Noosfero-Auth"] = (session[:user] != nil).to_s
  end

  def noosfero_session_check_after
    if headers['X-Noosfero-Auth'] == 'true'
      # special case: logout
      if !session[:user]
        session.delete
      end
    else
      # special case: login
      if session[:user]
        headers['X-Noosfero-Auth'] = 'true'
      end
    end
  end

end

class ActionController::CgiResponse

  def out_with_noosfero_session_check(output = $stdout)
    if headers['X-Noosfero-Auth'] == 'false'
      @cgi.send(:instance_variable_set, '@output_cookies', nil)
    end
    headers.delete('X-Noosfero-Auth')
    out_without_noosfero_session_check(output)
  end
  alias_method_chain :out, :noosfero_session_check

end

if Rails.env != 'development'
  ActionController::Base.send(:include, NoosferoHttpCaching)
end
