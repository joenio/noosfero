include BscPlugin::BscHelper

class BscPluginEnvironmentController < AdminController

  def new
    @bsc = BscPlugin::Bsc.new(params[:profile_data])
    if request.post? && @bsc.valid?
      @bsc.user = current_user
      @bsc.save!
      @bsc.add_admin(user)
      session[:notice] = _('Your Bsc was created.')
      redirect_to :controller => 'profile_editor', :profile => @bsc.identifier
    end
  end

  def save_validations
    enterprises = [Enterprise.find(params[:q].split(','))].flatten

    begin
      enterprises.each { |enterprise| enterprise.validated = true ; enterprise.save! }
      session[:notice] = _('Enterprises validated.')
      redirect_to :controller => 'admin_panel'
    rescue Exception => ex
      session[:notice] = _('Enterprise validations couldn\'t be saved.')
      logger.info ex
      redirect_to :action => 'validate_enterprises'
    end
  end

  def search_enterprise
    render :text => Enterprise.not_validated.find(:all, :conditions => ["type <> 'BscPlugin::Bsc' AND (name LIKE ? OR identifier LIKE ?)", "%#{params[:q]}%", "%#{params[:q]}%"]).
      map {|enterprise| {:id => enterprise.id, :name => enterprise.name} }.
      to_json
  end

  def report
    self.class.no_design_blocks
    @from = params[:from] ? Date.parse(params[:from]) : Date.today.at_beginning_of_month
    @to = params[:to] ? Date.parse(params[:to]) : Date.today
    @bscs = BscPlugin::Bsc.with_article_or_contract_in_period(@from, @to)
    @users = environment.users
    @relatorio = []

    respond_to do |format|
      format.html
      format.xml do
        stream = render_to_string(:action => 'report.xml.builder', :layout => false)
        send_data(stream, :type=>"text/xml",:filename => "bscs-report.xml")
      end
    end
  end
end
