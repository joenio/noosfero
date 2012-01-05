class Forum < Folder

  acts_as_having_posts :order => 'updated_at DESC'

  def self.short_description
    _('Forum')
  end

  def self.description
    _('An internet forum, also called message board, where discussions can be held.')
  end

  include ActionView::Helpers::TagHelper
  def to_html(options = {})
    lambda do
      render :file => 'content_viewer/forum_page'
    end
  end

  def forum?
    true
  end

  def self.icon_name(article = nil)
    'forum'
  end

  def notifiable?
    true
  end

  def first_paragraph
    paragraphs = Hpricot(body).search('p')
    paragraphs.empty? ? '' : paragraphs.first.to_html
  end
end
