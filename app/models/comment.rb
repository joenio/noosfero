class Comment < ActiveRecord::Base

  track_actions :leave_comment, :after_create, :keep_params => ["article.title", "article.url", "title", "url", "body"], :custom_target => :action_tracker_target 

  validates_presence_of :body
  belongs_to :article, :counter_cache => true
  belongs_to :author, :class_name => 'Person', :foreign_key => 'author_id'
  has_many :children, :class_name => 'Comment', :foreign_key => 'reply_of_id', :dependent => :destroy
  belongs_to :reply_of, :class_name => 'Comment', :foreign_key => 'reply_of_id'

  # unauthenticated authors:
  validates_presence_of :name, :if => (lambda { |record| !record.email.blank? })
  validates_presence_of :email, :if => (lambda { |record| !record.name.blank? })
  validates_format_of :email, :with => Noosfero::Constants::EMAIL_FORMAT, :if => (lambda { |record| !record.email.blank? })

  # require either a recognized author or an external person
  validates_presence_of :author_id, :if => (lambda { |rec| rec.name.blank? && rec.email.blank? })
  validates_each :name do |rec,attribute,value|
    if rec.author_id && (!rec.name.blank? || !rec.email.blank?)
      rec.errors.add(:name, _('%{fn} can only be informed for unauthenticated authors'))
    end
  end

  xss_terminate :only => [ :body, :title, :name ], :on => 'validation'

  def action_tracker_target
    self.article.profile
  end

  def author_name
    if author
      author.short_name
    else
      author_id ? '' : name
    end
  end

  def author_email
    author ? author.email : email
  end

  def author_link
    author ? author.url : email
  end

  def author_url
    author ? author.url : nil
  end

  def url
    article.view_url.merge(:anchor => anchor)
  end

  def message
    author_id ? _('(removed user)') : _('(unauthenticated user)')
  end

  def removed_user_image
    '/images/icons-app/person-minor.png'
  end

  def anchor
    "comment-#{id}"
  end

  def self.recent(limit = nil)
    self.find(:all, :order => 'created_at desc, id desc', :limit => limit)
  end

  after_save :notify_article
  after_destroy :notify_article
  def notify_article
    article.comments_updated
  end

  after_create do |comment|
    if comment.article.notify_comments? && !comment.article.profile.notification_emails.empty?
      Comment::Notifier.deliver_mail(comment)
    end
  end

  def replies
    @replies || children
  end

  def replies=(comments_list)
    @replies = comments_list
  end

  def self.as_thread
    result = {}
    root = []
    all.each do |c|
      c.replies = []
      result[c.id] ||= c
      c.reply_of_id.nil? ? root << c : result[c.reply_of_id].replies << c
    end
    root
  end

  include ApplicationHelper
  def reported_version(options = {})
    comment = self
    lambda { render_to_string(:partial => 'shared/reported_versions/comment', :locals => {:comment => comment}) }
  end

  def to_html(option={})
    body || ''
  end

  class Notifier < ActionMailer::Base
    def mail(comment)
      profile = comment.article.profile
      recipients profile.notification_emails
      from "#{profile.environment.name} <#{profile.environment.contact_email}>"
      subject _("[%s] you got a new comment!") % [profile.environment.name]
      body :recipient => profile.nickname || profile.name,
        :sender => comment.author_name,
        :sender_link => comment.author_link,
        :article_title => comment.article.name,
        :comment_url => comment.url,
        :comment_title => comment.title,
        :comment_body => comment.body,
        :environment => profile.environment.name,
        :url => profile.environment.top_url
    end
  end

end
