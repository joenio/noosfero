module FolderHelper

  include ShortFilename

  def list_articles(articles, recursive = false)
    if !articles.blank?
      articles = articles.paginate(
        :order => "updated_at DESC",
        :per_page => 10,
        :page => params[:npage]
      )

      render :file => 'shared/articles_list', :locals => {:articles => articles, :recursive => recursive}
    else
      content_tag('em', _('(empty folder)'))
    end
  end

  def available_articles(articles, user)
    articles.select {|article| article.display_to?(user)}
  end

  def display_article_in_listing(article, recursive = false, level = 0)
    article_link = if article.image?
         link_to('&nbsp;' * (level * 4) + image_tag(icon_for_article(article)) + short_filename(article.name), article.url.merge(:view => true))
       else
         link_to('&nbsp;' * (level * 4) + short_filename(article.name), article.url.merge(:view => true), :class => icon_for_article(article))
       end
    result = content_tag(
      'tr',
      content_tag('td', article_link )+
      content_tag('td', show_date(article.updated_at), :class => 'last-update'),
      :class => 'sitemap-item'
    )
    if recursive
      result + article.children.map {|item| display_article_in_listing(item, recursive, level + 1) }.join('')
    else
      result
    end
  end

  def icon_for_article(article)
    icon = article.class.icon_name(article)
    if (icon =~ /\//)
      icon
    else
      klasses = 'icon icon-' + icon
      if article.kind_of?(UploadedFile)
        klasses += ' icon-upload-file'
      end
      klasses
    end
  end

  def icon_for_new_article(type)
    "icon-new icon-new%s" % type.constantize.icon_name
  end

  def custom_options_for_article(article)
    @article = article
    content_tag('h4', _('Options')) +
    content_tag('div',
      content_tag(
        'div',
        check_box(:article, :published) +
        content_tag('label', _('This article must be published (visible to other people)'), :for => 'article_published')
      ) + (article.can_display_hits? ?
      content_tag(
        'div',
        check_box(:article, :display_hits) +
        content_tag('label', _('I want this article to display the number of hits it received'), :for => 'article_display_hits')
      ) : '') +
      hidden_field_tag('article[accept_comments]', 0)
    )
  end

  def cms_label_for_new_children
    _('New article')
  end

  def cms_label_for_edit
    _('Edit folder')
  end

end
