# Task is the base class of ... tasks! Its instances represents tasks that must
# be confirmed by someone (like an environment administrator) or by noosfero
# itself.
#
# The specific types of tasks <em>must</em> override the #perform method, so
# the actual action associated to the type of task can be performed. See the
# documentation of the #perform method for details. 
#
# This class has a +data+ field of type <tt>text</tt>, where you can store any
# type of data (as serialized Ruby objects) you need for your subclass (which
# will need to declare <ttserialize</tt> itself).
class Task < ActiveRecord::Base

  acts_as_having_settings :field => :data

  module Status
    # the status of tasks just created
    ACTIVE = 1

    # the status of a task that was cancelled.
    CANCELLED = 2

    # the status of a task that was successfully finished
    FINISHED = 3

    # the status of a task that was created but is not displayed yet
    HIDDEN = 4

    def self.names
      [nil, N_('Active'), N_('Cancelled'), N_('Finished'), N_('Hidden')]
    end
  end

  belongs_to :requestor, :class_name => 'Person', :foreign_key => :requestor_id
  belongs_to :target, :foreign_key => :target_id, :polymorphic => true

  validates_uniqueness_of :code, :on => :create
  validates_presence_of :code

  attr_protected :status

  def initialize(*args)
    super
    self.status = (args.first ? args.first[:status] : nil) || Task::Status::ACTIVE
  end

  attr_accessor :code_length
  before_validation_on_create do |task|
    if task.code.nil?
      task.code = Task.generate_code(task.code_length)
      while (Task.find_by_code(task.code))
        task.code = Task.generate_code(task.code_length)
      end
    end
  end

  after_create do |task|
    unless task.status == Task::Status::HIDDEN
      begin
        task.send(:send_notification, :created)
      rescue NotImplementedError => ex
        RAILS_DEFAULT_LOGGER.info ex.to_s
      end

      begin
        target_msg = task.target_notification_message
        TaskMailer.deliver_target_notification(task, target_msg) if target_msg
      rescue NotImplementedError => ex
        RAILS_DEFAULT_LOGGER.info ex.to_s
      end
    end
  end

  def self.all_types
    %w[Invitation EnterpriseActivation AddMember Ticket SuggestArticle  AddFriend CreateCommunity AbuseComplaint ApproveArticle CreateEnterprise ChangePassword EmailActivation InviteFriend InviteMember]
  end

  # this method finished the task. It calls #perform, which must be overriden
  # by subclasses. At the end a message (as returned by #finish_message) is
  # sent to the requestor with #notify_requestor.
  def finish
    transaction do
      self.status = Task::Status::FINISHED
      self.end_date = Time.now
      self.save!
      self.perform
      begin
        send_notification(:finished)
      rescue NotImplementedError => ex
        RAILS_DEFAULT_LOGGER.info ex.to_s
      end
    end
    after_finish
  end

  # :nodoc:
  def after_finish
  end

  def reject_explanation=(reject_explanation='')
    self.data[:reject_explanation] = reject_explanation
  end

  def reject_explanation
    self.data[:reject_explanation]
  end

  # this method cancels the task. At the end a message (as returned by
  # #cancel_message) is sent to the requestor with #notify_requestor.
  def cancel
    transaction do
      self.status = Task::Status::CANCELLED
      self.end_date = Time.now
      self.save!
      begin
        send_notification(:cancelled)
      rescue NotImplementedError => ex
        RAILS_DEFAULT_LOGGER.info ex.to_s
      end
    end
  end

  # Here are the tasks customizable options.

  def title
    _("Task")
  end

  def subject
    nil
  end

  def linked_subject
    nil
  end

  def information
    {:message => _('%{requestor} sent you a task.')}
  end

  def accept_details
    false
  end

  def reject_details
    false
  end

  def icon
    {:type => :defined_image, :src => "/images/icons-app/user-minor.png", :name => requestor.name, :url => requestor.url}
  end

  def default_decision
    'skip'
  end

  def accept_disabled?
    false
  end

  def reject_disabled?
    false
  end

  def skip_disabled?
    false
  end

  # The message that will be sent to the requestor of the task when the task is
  # created.
  def task_created_message
    raise NotImplementedError, "#{self} does not implement #task_created_message"
  end

  # The message that will be sent to the requestor of the task when its
  # finished.
  def task_finished_message
    raise NotImplementedError, "#{self} does not implement #task_finished_message"
  end

  # The message that will be sent to the requestor of the task when its
  # cancelled.
  def task_cancelled_message
    raise NotImplementedError, "#{self} does not implement #task_cancelled_message"
  end

  # The message that will be sent to the requestor of the task when its
  # activated.
  def task_activated_message
    raise NotImplementedError, "#{self} does not implement #task_cancelled_message"
  end

  # The message that will be sent to the *target* of the task when it is
  # created. The indent of this message is to notify the target about the
  # request that was just created for him/her. 
  #
  # The implementation in this class returns +nil+, what makes the notification
  # not to be sent. If you want to send a notification to the target upon task
  # creation, override this method and return a String.
  def target_notification_message
    raise NotImplementedError, "#{self} does not implement #target_notification_message"
  end

  def target_notification_description
    ''
  end

  # What permission is required to perform task?
  def permission
    :perform_task
  end

  def environment
    self.target.environment unless self.target.nil?
  end

  def activate
    self.status = Task::Status::ACTIVE
    save!
    begin
      self.send(:send_notification, :activated)
    rescue NotImplementedError => ex
      RAILS_DEFAULT_LOGGER.info ex.to_s
    end

    begin
      target_msg = target_notification_message
      TaskMailer.deliver_target_notification(self, target_msg) if target_msg
    rescue NotImplementedError => ex
      RAILS_DEFAULT_LOGGER.info ex.to_s
    end
  end

  protected

  # This method must be overrided in subclasses, and its implementation must do
  # the job the task is intended to. This method will be called when the finish
  # method is called.
  #
  # To cancel the finish of the task, you can throw an exception in perform.
  #
  # The implementation on Task class just does nothing.
  def perform
  end

  # Tells wheter e-mail notifications must be sent or not. Returns
  # <tt>true</tt> by default (i.e. notification are sent), but can be overriden
  # in subclasses to disable notifications or even to send notifications based
  # on some conditions.
  def sends_email?
    true
  end

  # sends notification e-mail about a task, if the task has a requestor.
  #
  # If 
  def send_notification(action)
    if sends_email?
      if self.requestor
        TaskMailer.send("deliver_task_#{action}", self)
      end
    end
  end

  named_scope :pending, :conditions => { :status =>  Task::Status::ACTIVE }
  named_scope :finished, :conditions => { :status =>  [Task::Status::CANCELLED, Task::Status::FINISHED] }
  named_scope :opened, :conditions => { :status =>  [Task::Status::ACTIVE, Task::Status::HIDDEN] }
  named_scope :of, lambda { |type| conditions = type ? "type LIKE '#{type}'" : "1=1"; {:conditions =>  [conditions]} }
  named_scope :order_by, lambda { |attribute, ord| {:order => "#{attribute} #{ord}"} }

  named_scope :to, lambda { |profile|
    environment_condition = nil
    if profile.person?
      envs_ids = Environment.find(:all).select{ |env| profile.is_admin?(env) }.map { |env| "target_id = #{env.id}"}.join(' OR ')
      environment_condition = envs_ids.blank? ? nil : "(target_type = 'Environment' AND (#{envs_ids}))"
    end
    profile_condition = "(target_type = 'Profile' AND target_id = #{profile.id})"
    { :conditions => [environment_condition, profile_condition].compact.join(' OR ') }
  }

  def opened?
    status == Task::Status::ACTIVE || status == Task::Status::HIDDEN
  end

  class << self

    # generates a random code string consisting of length characters (or 36 by
    # default) in the ranges a-z and 0-9
    def generate_code(length = nil)
      chars = ('a'..'z').to_a + ('0'..'9').to_a
      code = ""
      (length || chars.size).times do |n|
        code << chars[rand(chars.size)]
      end
      code
    end

    # finds a task by its (generated) code. Only returns a task with the
    # specified code AND with status = Task::Status::ACTIVE.
    #
    # Can be used in subclasses to find only their instances.
    def find_by_code(code)
      self.find(:first, :conditions => { :code => code, :status => Task::Status::ACTIVE })
    end

    def per_page
      15
    end

  end

end
