require File.dirname(__FILE__) + '/../test_helper'

class BlogTest < ActiveSupport::TestCase

  should 'be an article' do
    assert_kind_of Article, Blog.new
  end

  should 'provide proper description' do
    assert_kind_of String, Blog.description
  end

  should 'provide proper short description' do
    assert_kind_of String, Blog.short_description
  end

  should 'provide own icon name' do
    assert_not_equal Article.icon_name, Blog.icon_name
  end

  should 'provide blog as icon name' do
    assert_equal 'blog', Blog.icon_name
  end

  should 'identify as folder' do
    assert Blog.new.folder?, 'blog must identity itself as folder'
  end

  should 'identify as blog' do
    assert Blog.new.blog?, 'blog must identity itself as blog'
  end

  should 'create rss feed automatically' do
    p = create_user('testuser').person
    b = create(Blog, :profile_id => p.id, :name => 'blog_feed_test')
    assert_kind_of RssFeed, b.feed
  end

  should 'save feed options' do
    p = create_user('testuser').person
    p.articles << Blog.new(:profile => p, :name => 'blog_feed_test')
    p.blog.feed = { :limit => 7 }
    assert_equal 7, p.blog.feed.limit
  end

  should 'save feed options after create blog' do
    p = create_user('testuser').person
    p.articles << Blog.new(:profile => p, :name => 'blog_feed_test', :feed => { :limit => 7 })
    assert_equal 7, p.blog.feed.limit
  end

  should 'list 5 posts per page by default' do
    blog = Blog.new
    assert_equal 5, blog.posts_per_page
  end

  should 'update posts per page setting' do
    p = create_user('testuser').person
    p.articles << Blog.new(:profile => p, :name => 'Blog test')
    blog = p.blog
    blog.posts_per_page = 7
    assert blog.save!
    assert_equal 7, p.blog.posts_per_page
  end

  should 'has posts' do
    p = create_user('testuser').person
    blog = fast_create(Blog, :profile_id => p.id, :name => 'Blog test')
    post = fast_create(TextileArticle, :name => 'First post', :profile_id => p.id, :parent_id => blog.id)
    blog.children << post
    assert_includes blog.posts, post
  end

  should 'not includes rss feed in posts' do
    p = create_user('testuser').person
    blog = create(Blog, :profile_id => p.id, :name => 'Blog test')
    assert_includes blog.children, blog.feed
    assert_not_includes blog.posts, blog.feed
  end

  should 'list posts ordered by published at' do
    p = create_user('testuser').person
    blog = fast_create(Blog, :profile_id => p.id, :name => 'Blog test')
    newer = create(TextileArticle, :name => 'Post 2', :parent => blog, :profile => p)
    older = create(TextileArticle, :name => 'Post 1', :parent => blog, :profile => p, :published_at => Time.now - 1.month)
    assert_equal [newer, older], blog.posts
  end

  should 'has one external feed' do
    p = create_user('testuser').person
    blog = fast_create(Blog, :profile_id => p.id, :name => 'Blog test')
    efeed = blog.create_external_feed(:address => 'http://invalid.url')
    assert_equal efeed, blog.external_feed
  end

  should 'build external feed after save' do
    p = create_user('testuser').person
    blog = Blog.new(:profile => p, :name => 'Blog test')
    blog.external_feed_builder = { :address => 'feed address' }
    blog.save!
    assert blog.external_feed.valid?
  end

  should 'update external feed' do
    p = create_user('testuser').person
    blog = Blog.new(:profile => p, :name => 'Blog test')
    blog.save
    e = ExternalFeed.new(:address => 'feed address')
    e.blog = blog
    e.save
    blog.reload
    blog.external_feed_builder = { :address => 'address edited' }
    blog.save!
    assert_equal 'address edited', blog.external_feed.address
  end

  should 'invalid blog if has invalid external_feed' do
    p = create_user('testuser').person
    blog = Blog.new(:profile => p, :name => 'Blog test', :external_feed_builder => {:enabled => true})
    blog.save
    assert ! blog.valid?
  end

  should 'remove external feed when removing blog' do
    p = create_user('testuser').person
    blog = Blog.create!(:name => 'Blog test', :profile => p, :external_feed_builder => {:enabled => true, :address => "http://bli.org/feed"})
    assert blog.external_feed
    assert_difference ExternalFeed, :count, -1 do
      blog.destroy
    end
  end

  should 'profile has more then one blog' do
    p = create_user('testuser').person
    fast_create(Blog, :name => 'Blog test', :profile_id => p.id)
    assert_nothing_raised ActiveRecord::RecordInvalid do
      Blog.create!(:name => 'Another Blog', :profile => p)
    end
  end

  should 'not update slug from name for existing blog' do
    p = create_user('testuser').person
    blog = Blog.create!(:name => 'Blog test', :profile => p)
    assert_equal 'blog-test', blog.slug
    blog.name = 'Changed name'
    assert_not_equal 'changed-name', blog.slug
  end

  should 'display full posts by default' do
    blog = Blog.new
    assert_equal 'full', blog.visualization_format
  end

  should 'update visualization_format setting' do
    p = create_user('testuser').person
    p.articles << Blog.new(:profile => p, :name => 'Blog test')
    blog = p.blog
    blog.visualization_format = 'short'
    assert blog.save!
    assert_equal 'short', p.blog.visualization_format
  end

  should 'allow only full and short as visualization_format' do
    blog = Blog.new(:name => 'blog')
    blog.visualization_format = 'wrong_format'
    blog.valid?
    assert blog.errors.invalid?(:visualization_format)

    blog.visualization_format = 'short'
    blog.valid?
    assert !blog.errors.invalid?(:visualization_format)

    blog.visualization_format = 'full'
    blog.valid?
    assert !blog.errors.invalid?(:visualization_format)
  end

  should 'have posts' do
    assert Blog.new.has_posts?
  end

  should 'display posts in current language by default' do
    blog = Blog.new
    assert blog.display_posts_in_current_language
    assert blog.display_posts_in_current_language?
  end

  should 'update display posts in current language setting' do
    p = create_user('testuser').person
    p.articles << Blog.new(:profile => p, :name => 'Blog test')
    blog = p.blog
    blog.display_posts_in_current_language = false
    assert blog.save! && blog.reload
    assert !blog.reload.display_posts_in_current_language
    assert !blog.reload.display_posts_in_current_language?
  end

  #FIXME This should be used until there is a migration to fix all blogs that
  # already have folders inside them
  should 'not list folders in posts' do
    blog = fast_create(Blog)
    folder = fast_create(Folder, :parent_id => blog.id)
    article = fast_create(TextileArticle, :parent_id => blog.id)

    assert_not_includes blog.posts, folder
    assert_includes blog.posts, article
  end

  should 'not accept uploads' do
    folder = fast_create(Blog)
    assert !folder.accept_uploads?
  end

  should 'know when blog has or when has no posts' do
    blog = fast_create(Blog)
    assert blog.empty?
    fast_create(TextileArticle, :parent_id => blog.id)
    assert ! blog.empty?
  end

end
