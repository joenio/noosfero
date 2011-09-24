class TasksController < MyProfileController

  protect 'perform_task', :profile
  
  def index
    @filter = params[:filter_type].blank? ? nil : params[:filter_type]
    @tasks = Task.to(profile).pending.of(@filter).order_by('created_at', 'asc').paginate(:per_page => Task.per_page, :page => params[:page])
    @failed = params ? params[:failed] : {}
  end

  def processed
    @tasks = Task.to(profile).finished.sort_by(&:created_at)
  end

  VALID_DECISIONS = [ 'finish', 'cancel', 'skip' ]

  def close
    failed = {}

    if params[:tasks]
      params[:tasks].each do |id, value|
        decision = value[:decision]
        if request.post? && VALID_DECISIONS.include?(decision) && id && decision != 'skip'
          task = profile.find_in_all_tasks(id)
          begin
            task.update_attributes(value[:task])
            task.send(decision)
          rescue Exception => ex
            message = "#{task.title} (#{task.requestor ? task.requestor.name : task.author_name})"
            failed[ex.clean_message] ? failed[ex.clean_message] << message : failed[ex.clean_message] = [message]
          end
        end
      end
    end

    if failed.blank?
      session[:notice] = _("All decisions were applied successfully.")
    else
      session[:notice] = _("Some decisions couldn't be applied.")
    end
    redirect_to params.merge!(:action => 'index', :failed => failed)
  end

  def new
    @ticket = Ticket.new(params[:ticket])
    if params[:target_id]
      @ticket.target = profile.friends.find(params[:target_id])
    end
    @ticket.requestor = profile
    if request.post?
      if @ticket.save
        redirect_to :action => 'index'
      end
    end
  end

  def list_requested
    @tasks = Task.find_all_by_requestor_id(profile.id)
  end

  def ticket_details
    @ticket = Ticket.find(:first, :conditions => ['(requestor_id = ? or target_id = ?) and id = ?', profile.id, profile.id, params[:id]])
  end

end
