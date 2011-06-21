class BscPluginMyprofileController < MyProfileController

  def manage_associated_enterprises
    @associated_enterprises = profile.enterprises
    @pending_enterprises = profile.enterprise_requests.pending.map(&:enterprise)
  end

  def search_enterprise
    render :text => environment.enterprises.find(:all, :conditions => ['name LIKE ?', "%#{params[:q]}%"]).
      select { |enterprise| enterprise.bsc.nil? && !profile.already_requested?(enterprise)}.
      map {|enterprise| {:id => enterprise.id, :name => enterprise.name} }.
      to_json
  end

  def save_associations
      enterprises = [Enterprise.find(params[:q].split(','))].flatten
      to_remove = profile.enterprises - enterprises
      to_add = enterprises - profile.enterprises

      to_remove.each do |enterprise|
        enterprise.bsc = nil
        enterprise.save!
        profile.enterprises.delete(enterprise)
      end

      to_add.each do |enterprise|
        if enterprise.enabled
          BscPlugin::AssociateEnterprise.create!(:requestor => user, :target => enterprise, :bsc => profile)
        else
          enterprise.bsc = profile
          enterprise.save!
          profile.enterprises << enterprise
        end
      end

      session[:notice] = _('This Bsc associations were saved successfully.')
    begin
      redirect_to :controller => 'profile_editor'
    rescue Exception => ex
      session[:notice] = _('This Bsc associations couldn\'t be saved.')
      logger.info ex
      redirect_to :action => 'manage_associated_enterprises'
    end
  end

  def similar_enterprises
    name = params[:name]
    city = params[:city]

    result = []
    if !name.blank?
      enterprises = (profile.environment.enterprises - profile.enterprises).select { |enterprise| enterprise.bsc_id.nil? && enterprise.city == city && enterprise.name.downcase.include?(name.downcase)}
      result = enterprises.inject(result) {|result, enterprise| result << [enterprise.id, enterprise.name]}
    end
    render :text => result.to_json
  end

end
