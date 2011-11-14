require File.dirname(__FILE__) + '/../test_helper'
require 'cms_controller'

# Re-raise errors caught by the controller.
class CmsController; def rescue_action(e) raise e end; end

class CmsControllerTest < Test::Unit::TestCase

  fixtures :environments

  def setup
    @controller = CmsController.new
    @request    = ActionController::TestRequest.new
    @request.stubs(:ssl?).returns(true)
    @response   = ActionController::TestResponse.new

    @profile = create_user_with_permission('testinguser', 'post_content')
    login_as :testinguser
    @controller.stubs(:user).returns(@profile)
  end

  attr_reader :profile

  def test_local_files_reference
    assert_local_files_reference :get, :index, :profile => profile.identifier
  end

  def test_valid_xhtml
    assert_valid_xhtml
  end

  should 'list top level documents on index' do
    get :index, :profile => profile.identifier

    assert_template 'view'
    assert_equal profile, assigns(:profile)
    assert_nil assigns(:article)
    assert_kind_of Array, assigns(:articles)
  end

  should 'be able to view a particular document' do

    a = profile.articles.build(:name => 'blablabla')
    a.save!

    get :view, :profile => profile.identifier, :id => a.id

    assert_template 'view'
    assert_equal a, assigns(:article)
    assert_equal [], assigns(:articles)

    assert_kind_of Array, assigns(:articles)
  end

  should 'be able to edit a document' do
    a = profile.articles.build(:name => 'test')
    a.save!

    get :edit, :profile => profile.identifier, :id => a.id
    assert_template 'edit'
  end

  should 'be able to create a new document' do
    get :new, :profile => profile.identifier
    assert_response :success
    assert_template 'select_article_type'

    # TODO add more types here !!
    [ TinyMceArticle, TextileArticle ].each do |item|
      assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?type=#{item.name}" }
    end
  end

  should 'present edit screen after choosing article type' do
    get :new, :profile => profile.identifier, :type => 'TinyMceArticle'
    assert_template 'edit'

    assert_tag :tag => 'form', :attributes => { :action => "/myprofile/#{profile.identifier}/cms/new", :method => /post/i }, :descendant => { :tag => "input", :attributes => { :type => 'hidden', :value => 'TinyMceArticle' }}
  end

  should 'be able to save a document' do
    assert_difference Article, :count do
      post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'a test article', :body => 'the text of the article ...' }
    end
  end

  should 'display set as home page link to non folder' do
    a = fast_create(TextileArticle, :profile_id => profile.id, :updated_at => DateTime.now)
    Article.stubs(:short_description).returns('bli')
    get :index, :profile => profile.identifier
    assert_tag :tag => 'a', :content => 'Use as homepage', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/set_home_page/#{a.id}" }
  end

  should 'display set as home page link to folder' do
    a = Folder.new(:name => 'article folder'); profile.articles << a;  a.save!
    Article.stubs(:short_description).returns('bli')
    get :index, :profile => profile.identifier
    assert_tag :tag => 'a', :content => 'Use as homepage', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/set_home_page/#{a.id}" }
  end

  should 'not display set as home page if disabled in environment' do
    article = profile.articles.create!(:name => 'my new home page')
    folder = Folder.new(:name => 'article folder'); profile.articles << folder;  folder.save!
    Article.stubs(:short_description).returns('bli')
    env = Environment.default; env.enable('cant_change_homepage'); env.save!
    get :index, :profile => profile.identifier
    assert_no_tag :tag => 'a', :content => 'Use as homepage', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/set_home_page/#{article.id}" }
    assert_no_tag :tag => 'a', :content => 'Use as homepage', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/set_home_page/#{folder.id}" }
  end

  should 'be able to set home page' do
    a = profile.articles.build(:name => 'my new home page')
    a.save!

    assert_not_equal a, profile.home_page

    post :set_home_page, :profile => profile.identifier, :id => a.id

    profile.reload
    assert_equal a, profile.home_page
  end

  should 'be able to set home page even when profile description is invalid' do
    a = profile.articles.build(:name => 'my new home page')
    a.save!

    profile.description = 'a' * 600
    profile.save(false)

    assert !profile.valid?
    assert_not_equal a, profile.home_page

    post :set_home_page, :profile => profile.identifier, :id => a.id

    profile.reload
    assert_equal a, profile.home_page
  end

  should 'redirect to previous page after setting home page' do
    a = profile.articles.build(:name => 'my new home page')
    a.save!

    @request.env['HTTP_REFERER'] = '/random_page'
    post :set_home_page, :profile => profile.identifier, :id => a.id
    assert_redirected_to '/random_page'
  end

  should 'redirect to profile homepage after setting home page if no referer' do
    a = profile.articles.build(:name => 'my new home page')
    a.save!

    post :set_home_page, :profile => profile.identifier, :id => a.id
    assert_redirected_to profile.url
  end

  should 'set last_changed_by when creating article' do
    login_as(profile.identifier)

    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'changed by me', :body => 'content ...' }

    a = profile.articles.find_by_path('changed-by-me')
    assert_not_nil a
    assert_equal profile, a.last_changed_by
  end

  should 'set last_changed_by when updating article' do
    other_person = create_user('otherperson').person

    a = profile.articles.build(:name => 'my article')
    a.last_changed_by = other_person
    a.save!

    login_as(profile.identifier)
    post :edit, :profile => profile.identifier, :id => a.id, :article => { :body => 'new content for this article' }

    a.reload

    assert_equal profile, a.last_changed_by
  end

  should 'edit by using the correct template to display the editor depending on the mime-type' do
    a = profile.articles.build(:name => 'test document')
    a.save!
    assert_equal 'text/html', a.mime_type

    get :edit, :profile => profile.identifier, :id => a.id
    assert_response :success
    assert_template 'edit'
  end

  should 'convert mime-types to action names' do
    obj = mock
    obj.extend(CmsHelper)

    assert_equal 'text_html', obj.mime_type_to_action_name('text/html')
    assert_equal 'image', obj.mime_type_to_action_name('image')
    assert_equal 'application_xnoosferosomething', obj.mime_type_to_action_name('application/x-noosfero-something')
  end

  should 'be able to remove article' do
    a = profile.articles.build(:name => 'my-article')
    a.save!

    assert_difference Article, :count, -1 do
      post :destroy, :profile => profile.identifier, :id => a.id
      assert_redirected_to :action => 'index'
    end
  end

  should 'be able to acess Rss feed creation page' do
    login_as(profile.identifier)
    assert_nothing_raised do
      post :new, :type => "RssFeed", :profile => profile.identifier
    end
    assert_response 200
  end

  should 'be able to create a RSS feed' do
    login_as(profile.identifier)
    assert_difference RssFeed, :count do
      post :new, :type => RssFeed.name, :profile => profile.identifier, :article => { :name => 'new-feed', :limit => 15, :include => 'all' }
      assert_response :redirect
    end
  end

  should 'be able to update a RSS feed' do
    login_as(profile.identifier)
    feed = RssFeed.create!(:name => 'myfeed', :limit => 5, :include => 'all', :profile_id => profile.id)
    post :edit, :profile => profile.identifier, :id => feed.id, :article => { :limit => 77, :include => 'parent_and_children' }
    assert_response :redirect

    updated = RssFeed.find(feed.id)
    assert_equal 77, updated.limit
    assert_equal 'parent_and_children', updated.include
  end

  should 'be able to upload a file' do
    assert_difference UploadedFile, :count do
      post :new, :type => UploadedFile.name, :profile => profile.identifier, :article => { :uploaded_data => fixture_file_upload('/files/test.txt', 'text/plain')}
    end
    assert_not_nil profile.articles.find_by_path('test.txt')
    assigns(:article).destroy
  end

  should 'be able to update an uploaded file' do
    post :new, :type => UploadedFile.name, :profile => profile.identifier, :article => { :uploaded_data => fixture_file_upload('/files/test.txt', 'text/plain')}

    file = profile.articles.find_by_path('test.txt')
    assert_equal 'test.txt', file.name

    post :edit, :profile => profile.identifier, :id => file.id, :article => { :uploaded_data => fixture_file_upload('/files/test_another.txt', 'text/plain')}

    assert_equal 2, file.versions(true).size
  end

  should 'be able to upload an image' do
    assert_difference UploadedFile, :count do
      post :new, :type => UploadedFile.name, :profile => profile.identifier, :article => { :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png')}
    end
  end

   should 'be able to upload more than one file at once' do
    assert_difference UploadedFile, :count, 2 do
      post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/test.txt', 'text/plain'), fixture_file_upload('/files/rails.png', 'text/plain')]
    end
    assert_not_nil profile.articles.find_by_path('test.txt')
    assert_not_nil profile.articles.find_by_path('rails.png')
  end

  should 'upload to rigth folder' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    post :upload_files, :profile => profile.identifier, :parent_id => f.id, :uploaded_files => [fixture_file_upload('/files/test.txt', 'text/plain')]
    f.reload

    assert_not_nil f.children[0]
    assert_equal 'test.txt', f.children[0].name
  end

  should 'display destination folder of files when uploading file in root folder' do
    get :upload_files, :profile => profile.identifier

    assert_tag :tag => 'h5', :descendant => { :tag => 'code', :content => /\/#{profile.identifier}/ }
  end

  should 'display destination folder of files when uploading file' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    get :upload_files, :profile => profile.identifier, :parent_id => f.id

    assert_tag :tag => 'h5', :descendant => { :tag => 'code', :content => /\/#{profile.identifier}\/#{f.full_name}/}
  end

  should 'not crash on empty file' do
    assert_nothing_raised do
      post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/test.txt', 'text/plain'), '' ]
    end
    assert_not_nil profile.articles.find_by_path('test.txt')
  end

  should 'redirect to cms after uploading files' do
    post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/test.txt', 'text/plain')]
    assert_redirected_to :action => 'index'
  end

  should 'redirect to folder after uploading files' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    post :upload_files, :profile => profile.identifier, :parent_id => f.id, :uploaded_files => [fixture_file_upload('/files/test.txt', 'text/plain')]
    assert_redirected_to :action => 'view', :id => f.id
  end

  should 'display error message when file has more than max size' do
    UploadedFile.any_instance.stubs(:size).returns(UploadedFile.attachment_options[:max_size] + 1024)
    post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/rails.png', 'image/png')]
    assert assigns(:uploaded_files).first.size > UploadedFile.attachment_options[:max_size]
    assert_tag :tag => 'div', :attributes => { :class => 'errorExplanation', :id => 'errorExplanation' }
  end

  should 'not display error message when file has less than max size' do
    UploadedFile.any_instance.stubs(:size).returns(UploadedFile.attachment_options[:max_size] - 1024)
    post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/rails.png', 'image/png')]
    assert_no_tag :tag => 'div', :attributes => { :class => 'errorExplanation', :id => 'errorExplanation' }
  end

  should 'not redirect when some file has errors' do
    UploadedFile.any_instance.stubs(:size).returns(UploadedFile.attachment_options[:max_size] + 1024)
    post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/rails.png', 'image/png')]
    assert_response :success
    assert_template 'upload_files'
  end

  should 'offer to create new content' do
    get :index, :profile => profile.identifier
    assert_response :success
    assert_template 'view'
    assert_tag :tag => 'a', :attributes => { :title => 'New content', :href => "/myprofile/#{profile.identifier}/cms/new?cms=true"}
  end

  should 'offer to create new content when viewing an article' do
    article = fast_create(Article, :profile_id => profile.id)
    get :view, :profile => profile.identifier, :id => article.id
    assert_response :success
    assert_template 'view'
    assert_tag :tag => 'a', :attributes => { :title => 'New content', :href => "/myprofile/#{profile.identifier}/cms/new?cms=true&amp;parent_id=#{article.id}"}
  end

  should 'offer to create children' do
    Article.any_instance.stubs(:allow_children?).returns(true)

    article = Article.new(:name => 'test')
    article.profile = profile
    article.save!

    get :new, :profile => profile.identifier, :parent_id => article.id, :cms => true
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?parent_id=#{article.id}&amp;type=TextileArticle"}
  end

  should 'not offer to create children if article does not accept them' do
    Article.any_instance.stubs(:allow_children?).returns(false)

    article = Article.new(:name => 'test')
    article.profile = profile
    article.save!

    get :view, :profile => profile.identifier, :id => article.id
    assert_response :success
    assert_template 'view'
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?parent_id=#{article.id}"}
  end

  should 'refuse to create children of non-child articles' do
    Article.any_instance.stubs(:allow_children?).returns(false)

    article = Article.new(:name => 'test')
    article.profile = profile
    article.save!

    assert_no_difference UploadedFile, :count do
      assert_raise ArgumentError do
        post :new, :type => UploadedFile.name, :parent_id => article.id, :profile => profile.identifier, :article => { :uploaded_data => fixture_file_upload('/files/test.txt', 'text/plain')}
      end
    end
  end

  should 'display max size of uploaded file' do
    get :upload_files, :profile => profile.identifier
    assert_tag :tag => 'h3', :content => /max size #{UploadedFile.max_size.to_humanreadable}/
  end

  should 'display link for selecting categories' do
    # FIXME
    assert true
    #env = Environment.default
    #top = env.categories.build(:display_in_menu => true, :name => 'Top-Level category'); top.save!
    #c1  = env.categories.build(:display_in_menu => true, :name => "Test category 1", :parent_id => top.id); c1.save!
    #c2  = env.categories.build(:display_in_menu => true, :name => "Test category 2", :parent_id => top.id); c2.save!
    #c3  = env.categories.build(:display_in_menu => true, :name => "Test Category 3", :parent_id => top.id); c3.save!

    #article = Article.new(:name => 'test')
    #article.profile = profile
    #article.save!

    #get :edit, :profile => profile.identifier, :id => article.id

    #[c1,c2,c3].each do |item|
    #  assert_tag :tag => 'a', :attributes => { :id => "select-category-#{item.id}-link" }
    #end
  end

  should 'be able to associate articles with categories' do
    env = Environment.default
    c1 = env.categories.build(:name => "Test category 1"); c1.save!
    c2 = env.categories.build(:name => "Test category 2"); c2.save!
    c3 = env.categories.build(:name => "Test Category 3"); c3.save!

    # post is in c1 and c3
    post :new, :type => TextileArticle.name, :profile => profile.identifier, :article => { :name => 'adding-categories-test', :category_ids => [ c1.id, c3.id] }

    saved = profile.articles.find_by_name('adding-categories-test')
    assert_includes saved.categories, c1
    assert_not_includes saved.categories, c2
    assert_includes saved.categories, c3
  end

  should 'not associate articles with category twice' do
    env = Environment.default
    c1 = env.categories.build(:name => "Test category 1"); c1.save!
    c2 = env.categories.build(:name => "Test category 2"); c2.save!
    c3 = env.categories.build(:name => "Test Category 3"); c3.save!

    # post is in c1, c3 and c3
    post :new, :type => TextileArticle.name, :profile => profile.identifier, :article => { :name => 'adding-categories-test', :category_ids => [ c1.id, c3.id, c3.id ] }

    saved = profile.articles.find_by_name('adding-categories-test')
    assert_equal [c1, c3], saved.categories
  end

  should 'filter html with white_list from tiny mce article name' do
    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => "<strong>test</strong>", :body => 'the text of the article ...' }
    assert_equal "<strong>test</strong>", assigns(:article).name
  end

  should 'filter html with white_list from tiny mce article abstract' do
    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'article', :abstract => "<script>alert('test')</script> article", :body => 'the text of the article ...' }
    assert_equal " article", assigns(:article).abstract
  end

  should 'filter html with white_list from tiny mce article body' do
    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'article', :abstract => 'abstract', :body => "the <script>alert('text')</script> of article ..." }
    assert_equal "the  of article ...", assigns(:article).body
  end

  should 'not filter html tags permitted from tiny mce article body' do
    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'article', :abstract => 'abstract', :body => "<b>the</b> <script>alert('text')</script> <strong>of</strong> article ..." }
    assert_equal "<b>the</b>  <strong>of</strong> article ...", assigns(:article).body
  end

  should 'sanitize tags' do
    post :new, :type => 'TextileArticle', :profile => profile.identifier, :article => { :name => 'a test article', :body => 'the text of the article ...', :tag_list => 'tag1, <strong>tag2</strong>' }
    assert_sanitized assigns(:article).tag_list.names.join(', ')
  end

  should 'keep informed parent_id' do
    get :new, :profile => @profile.identifier, :parent_id => profile.home_page.id, :type => 'TextileArticle'
    assert_tag :tag => 'input', :attributes => { :name => 'parent_id', :value => profile.home_page.id }
  end

  should 'list folders before others' do
    profile.articles.destroy_all

    folder1 = fast_create(Folder, :profile_id => profile.id, :updated_at => DateTime.now - 1.hour)
    article = fast_create(TextileArticle, :profile_id => profile.id, :updated_at => DateTime.now)
    folder2 = fast_create(Folder, :profile_id => profile.id, :updated_at => DateTime.now + 1.hour)

    get :index, :profile => profile.identifier
    assert_equal [folder2, folder1, article], assigns(:articles)
  end

  should 'list folders inside another folder' do
    profile.articles.destroy_all

    parent = fast_create(Folder, :profile_id => profile.id)
    folder1 = fast_create(Folder, :parent_id => parent.id, :profile_id => profile.id, :updated_at => DateTime.now - 1.hour)
    article = fast_create(TextileArticle, :parent_id => parent.id, :profile_id => profile.id, :updated_at => DateTime.now)
    folder2 = fast_create(Folder, :parent_id => parent.id, :profile_id => profile.id, :updated_at => DateTime.now + 1.hour)

    get :view, :profile => profile.identifier, :id => parent.id
    assert_equal [folder2, folder1, article], assigns(:articles)
  end

  should 'offer to create new top-level folder' do
    get :new, :profile => profile.identifier, :cms => true
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?type=Folder"}
  end

  should 'offer to create sub-folder' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    get :new, :profile => profile.identifier, :parent_id => f.id, :cms => true

    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?parent_id=#{f.id}&amp;type=Folder" }
  end

  should 'redirect to article after creating top-level article' do
    post :new, :profile => profile.identifier, :type => 'TextileArticle', :article => { :name => 'top-level-article' }

    assert_redirected_to @profile.articles.find_by_name('top-level-article').url
  end

  should 'redirect to article after creating article inside a folder' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    post :new, :profile => profile.identifier, :type => 'TextileArticle', :parent_id => f.id, :article => { :name => 'article-inside-folder' }

    assert_redirected_to @profile.articles.find_by_name('article-inside-folder').url
  end

  should 'redirect back to article after editing top-level article' do
    f = Folder.new(:name => 'top-level-article'); profile.articles << f; f.save!
    post :edit, :profile => profile.identifier, :id => f.id
    assert_redirected_to @profile.articles.find_by_name('top-level-article').url
  end

  should 'redirect back to article after editing article inside a folder' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    a = TextileArticle.create!(:parent => f, :name => 'article-inside-folder', :profile_id => profile.id)

    post :edit, :profile => profile.identifier, :id => a.id
    assert_redirected_to @profile.articles.find_by_name('article-inside-folder').url
  end

  should 'point back to index when cancelling creation of top-level article' do
    get :new, :profile => profile.identifier, :type => 'Folder'
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms" }, :descendant => { :content => /Cancel/ }
  end

  should 'point back to index when cancelling edition of top-level article' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    get :edit, :profile => profile.identifier, :id => f.id

    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms" }, :descendant => { :content => /Cancel/ }
  end

  should 'point back to folder when cancelling creation of an article inside it' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    get :new, :profile => profile.identifier, :type => 'Folder', :parent_id => f.id

    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/view/#{f.id}" }, :descendant => { :content => /Cancel/ }
  end

  should 'point back to folder when cancelling edition of an article inside it' do
    f = Folder.new(:name => 'f'); profile.articles << f; f.save!
    a = TextileArticle.create!(:name => 'test', :parent => f, :profile_id => profile.id)
    get :edit, :profile => profile.identifier, :id => a.id

    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/view/#{f.id}" }, :descendant => { :content => /Cancel/ }
  end

  should 'link to page explaining about categorization' do
    get :edit, :profile => profile.identifier, :id => profile.home_page.id
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/why_categorize" }
  end

  should 'present popup' do
    get :why_categorize, :profile => profile.identifier
    assert_template 'why_categorize'
    assert_no_tag :tag => 'body'
  end

  should 'display OK button on why_categorize popup' do
    get :why_categorize, :profile => profile.identifier
    assert_tag :tag => 'a', :attributes => { :rel => 'deactivate'} # lightbox close button
  end

  should 'display published option' do
    get :edit, :profile => profile.identifier, :id => profile.home_page.id
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[published]', :checked => 'checked' }
  end

  should "display properly a non-published articles' status" do
    article = profile.articles.create!(:name => 'test', :published => false)

    get :edit, :profile => profile.identifier, :id => article.id
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[published]' }
    assert_no_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[published]', :checked => 'checked' }
  end

  should 'be able to add image with alignment' do
    post :new, :type => 'TinyMceArticle', :profile => profile.identifier, :article => { :name => 'image-alignment', :body => "the text of the article with image <img src='#' align='right'/> right align..." }
    saved = TinyMceArticle.find_by_name('image-alignment')
    assert_match /<img src="#" align="right" \/>/, saved.body
  end

  should 'not be able to add image with alignment when textile' do
    post :new, :type => 'TextileArticle', :profile => profile.identifier, :article => { :name => 'image-alignment', :body => "the text of the article with image <img src='#' align='right'/> right align..." }
    saved = TextileArticle.find_by_name('image-alignment')
    assert_no_match /align="right"/, saved.body
  end

  should 'be able to create a new event document' do
    get :new, :type => 'Event', :profile => profile.identifier
    assert_response :success
    assert_tag :input, :attributes => { :id => 'article_link' }
  end

  should 'not make enterprise homepage available to person' do
    @controller.stubs(:profile).returns(profile)
    assert_not_includes @controller.available_article_types, EnterpriseHomepage
  end

  should 'make enterprise homepage available to enterprises' do
    @controller.stubs(:profile).returns(fast_create(Enterprise, :name => 'test_ent', :identifier => 'test_ent'))
    assert_includes @controller.available_article_types, EnterpriseHomepage
  end

  should 'update categories' do
    env = Environment.default
    top = env.categories.create!(:display_in_menu => true, :name => 'Top-Level category')
    c1  = env.categories.create!(:display_in_menu => true, :name => "Test category 1", :parent_id => top.id)
    c2  = env.categories.create!(:display_in_menu => true, :name => "Test category 2", :parent_id => top.id)
    get :update_categories, :profile => profile.identifier, :category_id => top.id
    assert_template 'shared/_select_categories'
    assert_equal top, assigns(:current_category)
    assert_equal [c1, c2], assigns(:categories)
  end

  should 'record when coming from public view on edit' do
    article = @profile.articles.create!(:name => 'myarticle')

    @request.expects(:referer).returns('http://colivre.net/testinguser/myarticle').at_least_once

    get :edit, :profile => 'testinguser', :id => article.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => /^https?:\/\/colivre.net\/testinguser\/myarticle/ }
  end

  should 'detect when comming from home page' do
    @request.expects(:referer).returns('http://colivre.net/testinguser').at_least_once
    get :edit, :profile => 'testinguser', :id => @profile.home_page.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => @request.referer }
  end

  should 'go back to public view when saving coming from there' do
    article = @profile.articles.create!(:name => 'myarticle')

    post :edit, :profile => 'testinguser', :id => article.id, :back_to => 'public_view'
    assert_redirected_to article.url
  end

  should 'record as coming from public view when creating article' do
    @request.expects(:referer).returns('http://colivre.net/testinguser/testingusers-home-page').at_least_once
    get :new, :profile => 'testinguser', :type => 'TextileArticle'
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => 'http://colivre.net/testinguser/testingusers-home-page' }
  end

  should 'go to public view after creating article coming from there' do
    post :new, :profile => 'testinguser', :type => 'TextileArticle', :back_to => 'public_view', :article => { :name => 'new-article-from-public-view' }
    assert_response :redirect
    assert_redirected_to @profile.articles.find_by_name('new-article-from-public-view').url
  end

  should 'keep the back_to hint in unsuccessfull saves' do
    post :new, :profile => 'testinguser', :type => 'TextileArticle', :back_to => 'public_view', :article => { }
    assert_response :success
    assert_tag :tag => "input", :attributes => { :type => 'hidden', :name => 'back_to', :value => 'public_view' }
  end

  should 'create a private article child of private folder' do
    folder = Folder.new(:name => 'my intranet', :published => false); profile.articles << folder; folder.save!

    post :new, :profile => profile.identifier, :type => 'TextileArticle', :parent_id => folder.id, :article => { :name => 'new-private-article'}
    folder.reload

    assert !assigns(:article).published?
    assert_equal 'new-private-article', folder.children[0].name
    assert !folder.children[0].published?
  end

  should 'load communities for that the user belongs' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm')
    c.affiliate(profile, Profile::Roles.all_roles(c.environment.id))
    a = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')

    get :publish, :profile => profile.identifier, :id => a.id

    assert_equal [c], assigns(:groups)
    assert_template 'publish'
  end

  should 'publish the article in the selected community if community is not moderated' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm', :moderated_articles => false)
    c.affiliate(profile, Profile::Roles.all_roles(c.environment.id))
    article = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')

    assert_difference article.class, :count do
      post :publish, :profile => profile.identifier, :id => article.id, :marked_groups => {c.id.to_s => {:name => 'bli', :group_id => c.id.to_s}}
      assert_equal [{'group' => c, 'name' => 'bli'}], assigns(:marked_groups)
    end
  end

  should 'create a new event after publishing an event' do
    c = fast_create(Community)
    c.affiliate(profile, Profile::Roles.all_roles(c.environment.id))
    a = Event.create!(:name => "Some event", :profile => profile, :start_date => Date.today)

    assert_difference Event, :count do
      post :publish, :profile => profile.identifier, :id => a.id, :marked_groups => {c.id.to_s => {:name => 'bli', :group_id => c.id.to_s}}
    end
  end

  should "not crash if there is a post and no portal community defined" do
    Environment.any_instance.stubs(:portal_community).returns(nil)
    article = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')
    assert_nothing_raised do
      post :publish_on_portal_community, :profile => profile.identifier, :id => article.id, :name => article.name
    end
  end

  should 'publish the article on portal community if it is not moderated' do
    portal_community = fast_create(Community)
    portal_community.moderated_articles = false
    portal_community.save
    Environment.any_instance.stubs(:portal_community).returns(portal_community)
    article = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')

    assert_difference article.class, :count do
      post :publish_on_portal_community, :profile => profile.identifier, :id => article.id, :name => article.name
    end
  end

  should 'create a task for article approval if community is moderated' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm', :moderated_articles => true)
    c.affiliate(profile, Profile::Roles.all_roles(c.environment.id))
    a = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')

    assert_no_difference a.class, :count do
      assert_difference ApproveArticle, :count do
        assert_difference c.tasks, :count do
          post :publish, :profile => profile.identifier, :id => a.id, :marked_groups => {c.id.to_s => {:name => 'bli', :group_id => c.id.to_s}}
          assert_equal [{'group' => c, 'name' => 'bli'}], assigns(:marked_groups)
        end
      end
    end
  end

  should 'create a task for article approval if portal community is moderated' do
    portal_community = fast_create(Community)
    portal_community.moderated_articles = true
    portal_community.save
    Environment.any_instance.stubs(:portal_community).returns(portal_community)
    article = profile.articles.create!(:name => 'something intresting', :body => 'ruby on rails')

    assert_no_difference article.class, :count do
      assert_difference ApproveArticle, :count do
        assert_difference portal_community.tasks, :count do
          post :publish_on_portal_community, :profile => profile.identifier, :id => article.id, :name => article.name
        end
      end
    end
  end

  should 'require ssl in general' do
    Environment.default.update_attribute(:enable_ssl, true)
    @request.expects(:ssl?).returns(false).at_least_once
    get :index, :profile => 'testinguser'
    assert_redirected_to :protocol => 'https://'
  end

  should 'accept ajax connections to new action without ssl' do
    @request.expects(:ssl?).returns(false).at_least_once
    xml_http_request :get, :new, :profile => 'testinguser'
    assert_response :success
  end

  should 'not loose type argument in new action when redirecting to ssl' do
    Environment.default.update_attribute(:enable_ssl, true)
    @request.expects(:ssl?).returns(false).at_least_once
    get :new, :profile => 'testinguser', :type => 'Folder'
    assert_redirected_to :protocol => 'https://', :action => 'new', :type => 'Folder'
  end

  should 'not accept non-ajax connections to new action without ssl' do
    Environment.default.update_attribute(:enable_ssl, true)
    @request.expects(:ssl?).returns(false).at_least_once
    get :new, :profile => 'testinguser'
    assert_redirected_to :protocol => 'https://'
  end

  should 'display categories if environment disable_categories disabled' do
    Environment.any_instance.stubs(:enabled?).with(anything).returns(false)
    a = profile.articles.create!(:name => 'test')
    get :edit, :profile => profile.identifier, :id => a.id
    assert_tag :tag => 'div', :descendant => { :tag => 'h4', :content => 'Categorize your article' }
  end

  should 'not display categories if environment disable_categories enabled' do
    Environment.any_instance.stubs(:enabled?).with(anything).returns(true)
    a = profile.articles.create!(:name => 'test')
    get :edit, :profile => profile.identifier, :id => a.id
    assert_no_tag :tag => 'div', :descendant => { :tag => 'h4', :content => 'Categorize your article' }
  end

  should 'display posts per page input with default value on edit blog' do
    n = Blog.new.posts_per_page.to_s
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'select', :attributes => { :name => 'article[posts_per_page]' }, :child => { :tag => 'option', :attributes => {:value => n, :selected => 'selected'} }
  end

  should 'display options for blog visualization with default value on edit blog' do
    format = Blog.new.visualization_format
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'select', :attributes => { :name => 'article[visualization_format]' }, :child => { :tag => 'option', :attributes => {:value => 'full', :selected => 'selected'} }
  end

  should 'not offer to create special article types' do
    get :new, :profile => profile.identifier
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?type=Blog"}
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?type=Forum"}
  end

  should 'not offer folders if in a blog' do
    blog = fast_create(Blog, :profile_id => profile.id)
    get :new, :profile => profile.identifier, :parent_id => blog.id, :cms => true
    types = assigns(:article_types).map {|t| t[:name]}
    Article.folder_types.each do |type|
      assert_not_includes types, type
    end
  end

  should 'offer to edit a blog' do
    profile.articles << Blog.new(:name => 'blog test', :profile => profile)

    profile.articles.reload
    assert profile.has_blog?

    b = profile.blog
    get :index, :profile => profile.identifier
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/edit/#{b.id}"}
  end

  should 'not offer to add folder to blog' do
    profile.articles << Blog.new(:name => 'blog test', :profile => profile)

    profile.articles.reload
    assert profile.has_blog?

    get :view, :profile => profile.identifier, :id => profile.blog.id
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?parent_id=#{profile.blog.id}&amp;type=Folder"}
  end

  should 'not show feed subitem for blog' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile)

    profile.articles.reload
    assert profile.has_blog?

    get :view, :profile => profile.identifier, :id => profile.blog.id

    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/edit/#{profile.blog.feed.id}" }
  end

  should 'update feed options by edit blog form' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.blog.id, :article => { :feed => { :limit => 7 } }
    assert_equal 7, profile.blog.feed.limit
  end

  should 'not offer folder to blog articles' do
    @controller.stubs(:profile).returns(fast_create(Enterprise, :name => 'test_ent', :identifier => 'test_ent'))
    blog = Blog.create!(:name => 'Blog for test', :profile => profile)
    @controller.stubs(:params).returns({ :parent_id => blog.id })

    assert_not_includes @controller.available_article_types, Folder
  end

  should 'not offer rssfeed to blog articles' do
    @controller.stubs(:profile).returns(fast_create(Enterprise, :name => 'test_ent', :identifier => 'test_ent'))
    blog = Blog.create!(:name => 'Blog for test', :profile => profile)
    @controller.stubs(:params).returns({ :parent_id => blog.id })

    assert_not_includes @controller.available_article_types, RssFeed
  end

  should 'update blog posts_per_page setting' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.blog.id, :article => { :posts_per_page => 5 }
    profile.blog.reload
    assert_equal 5, profile.blog.posts_per_page
  end

  should "display 'New content' when create children of folder" do
    a = Folder.new(:name => 'article folder'); profile.articles << a;  a.save!
    Article.stubs(:short_description).returns('bli')
    get :view, :profile => profile.identifier, :id => a
    assert_tag :tag => 'a', :content => 'New content'
  end

  should "display 'New content' when create children of blog" do
    a = Blog.create!(:name => 'blog_for_test', :profile => profile)
    Article.stubs(:short_description).returns('bli')
    get :view, :profile => profile.identifier, :id => a
    assert_tag :tag => 'a', :content => 'New content'
  end

  should 'offer confirmation to remove article' do
    a = profile.articles.create!(:name => 'my-article')
    get :destroy, :profile => profile.identifier, :id => a.id
    assert_response :success
    assert_tag :tag => 'input', :attributes => {:type => 'submit', :value => 'Yes, I want.' }
  end

  should 'display notify comments option' do
    a = profile.articles.create!(:name => 'test')
    get :edit, :profile => profile.identifier, :id => a.id
    assert :tag => 'input', :attributes => {:name => 'article[notify_comments]', :value => 1}
  end

  should 'go to blog after create it' do
    assert_difference Blog, :count do
      post :new, :type => Blog.name, :profile => profile.identifier, :article => { :name => 'my-blog' }, :back_to => 'control_panel'
    end
    assert_redirected_to @profile.articles.find_by_name('my-blog').view_url
  end

  should 'back to blog after config blog' do
    profile.articles << Blog.new(:name => 'my-blog', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.blog.id

    assert_redirected_to @profile.articles.find_by_name('my-blog').view_url
  end

  should 'back to control panel if cancel create blog' do
    get :new, :profile => profile.identifier, :type => Blog.name
    assert_tag :tag => 'a', :content => 'Cancel', :attributes => { :href => /\/myprofile\/#{profile.identifier}/ }
  end

  should 'back to control panel if cancel config blog' do
    profile.articles << Blog.new(:name => 'my-blog', :profile => profile)
    get :edit, :profile => profile.identifier, :id => profile.blog.id
    assert_tag :tag => 'a', :content => 'Cancel', :attributes => { :href => /\/myprofile\/#{profile.identifier}/ }
  end

  should 'create icon upload file in folder' do
    f = Gallery.create!(:name => 'test_folder', :profile => profile)
    post :new, :profile => profile.identifier,
               :type => UploadedFile.name,
               :parent_id => f.id,
               :article => {:uploaded_data => fixture_file_upload('/files/rails.png', 'image/png')}

    process_delayed_job_queue
    file = profile.articles.find_by_name('rails.png')
    assert File.exists?(file.class.icon_name(file))
    file.destroy
  end

  should 'create icon upload file' do
    post :new, :profile => profile.identifier,
               :type => UploadedFile.name,
               :article => {:uploaded_data => fixture_file_upload('/files/rails.png', 'image/png')}

    process_delayed_job_queue
    file = profile.articles.find_by_name('rails.png')
    assert File.exists?(file.class.icon_name(file))
    file.destroy
  end

  should 'record when coming from public view on upload files' do
    folder = Folder.create!(:name => 'testfolder', :profile => profile)

    @request.expects(:referer).returns("http://colivre.net/#{profile.identifier}/#{folder.slug}").at_least_once

    get :upload_files, :profile => profile.identifier, :parent_id => folder.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => /^https?:\/\/colivre.net\/#{profile.identifier}\/#{folder.slug}/ }
  end

  should 'detect when comming from home page to upload files' do
    folder = Folder.create!(:name => 'testfolder', :profile => profile)
    @request.expects(:referer).returns("http://colivre.net/#{profile.identifier}").at_least_once
    @controller.stubs(:profile).returns(profile)
    get :upload_files, :profile => profile.identifier, :parent_id => folder.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => @request.referer }
  end

  should 'go back to public view when upload files coming from there' do
    folder = Folder.create!(:name => 'test_folder', :profile => profile)
    @request.expects(:referer).returns(folder.view_url).at_least_once

    post :upload_files, :profile => profile.identifier, :parent_id => folder.id, :back_to => @request.referer, :uploaded_files => [fixture_file_upload('files/rails.png', 'image/png')]
    assert_template nil
    assert_redirected_to folder.view_url
  end

  should 'record when coming from public view on edit files with view true' do
    file = UploadedFile.create!(:profile => profile, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))

    @request.expects(:referer).returns("http://colivre.net/#{profile.identifier}/#{file.slug}?view=true").at_least_once

    get :edit, :profile => profile.identifier, :id => file.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => /^https?:\/\/colivre.net\/#{profile.identifier}\/#{file.slug}?.*view=true/ }
  end

  should 'detect when comming from home page to edit files with view true' do
    file = UploadedFile.create!(:profile => profile, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))

    @request.expects(:referer).returns("http://colivre.net/#{profile.identifier}?view=true").at_least_once
    @controller.stubs(:profile).returns(profile)
    get :edit, :profile => profile.identifier, :id => file.id
    assert_tag :tag => 'input', :attributes => { :type => 'hidden', :name => 'back_to', :value => @request.referer }
    assert_tag :tag => 'a', :descendant => { :content => 'Cancel' }, :attributes => { :href => @request.referer }
  end

  should 'go back to public view when edit files coming from there with view true' do
    file = UploadedFile.create!(:profile => profile, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))
    @request.expects(:referer).returns("http://colivre.net/#{profile.identifier}/#{file.slug}?view=true").at_least_once

    post :edit, :profile => profile.identifier, :id => file.id, :back_to => @request.referer, :article => {:abstract => 'some description'}
    assert_template nil
    assert_redirected_to file.url.merge(:view => true)
  end

  should 'display external feed options when edit blog' do
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][enabled]' }
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][address]' }
  end

  should "display 'Fetch posts from an external feed' checked if blog has enabled external feed" do
    profile.articles << Blog.new(:name => 'test blog', :profile => profile)
    profile.blog.create_external_feed(:address => 'address', :enabled => true)
    get :edit, :profile => profile.identifier, :id => profile.blog.id
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][enabled]', :checked => 'checked' }
  end

  should "display 'Fetch posts from an external feed' unchecked if blog has disabled external feed" do
    profile.articles << Blog.new(:name => 'test blog', :profile => profile)
    profile.blog.create_external_feed(:address => 'address', :enabled => false)
    get :edit, :profile => profile.identifier, :id => profile.blog.id
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][enabled]', :checked => nil }
  end

  should "hide external feed options when 'Fetch posts from an external feed' unchecked" do
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][enabled]', :checked => nil }
    assert_tag :tag => 'div', :attributes => { :id => 'external-feed-options', :style => 'display: none' }
  end

  should 'only_once option marked by default' do
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'input', :attributes => { :name => 'article[external_feed_builder][only_once]', :checked => 'checked', :value => 'true' }
  end

  should 'display media listing when it is TinyMceArticle and enabled on environment' do
    e = Environment.default
    e.enable('media_panel')
    e.save!

    image_folder = Folder.create(:profile => profile, :name => 'Image folder')
    non_image_folder = Folder.create(:profile => profile, :name => 'Non image folder')

    image = UploadedFile.create!(:profile => profile, :parent => image_folder, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))
    file = UploadedFile.create!(:profile => profile, :parent => non_image_folder, :uploaded_data => fixture_file_upload('/files/test.txt', 'text/plain'))

    get :new, :profile => profile.identifier, :type => 'TinyMceArticle'
    assert_tag :div, :attributes => { :class => "text-editor-sidebar" }
  end

  should 'not display media listing when it is Folder' do
    image_folder = Folder.create(:profile => profile, :name => 'Image folder')
    non_image_folder = Folder.create(:profile => profile, :name => 'Non image folder')

    image = UploadedFile.create!(:profile => profile, :parent => image_folder, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))
    file = UploadedFile.create!(:profile => profile, :parent => non_image_folder, :uploaded_data => fixture_file_upload('/files/test.txt', 'text/plain'))

    get :new, :profile => profile.identifier, :type => 'Folder'
    assert_no_tag :div, :attributes => { :id => "text-editor-sidebar" }
  end

  should "display 'Publish' when profile is a person" do
    a = fast_create(TextileArticle, :profile_id => profile.id, :updated_at => DateTime.now)
    Article.stubs(:short_description).returns('bli')
    get :index, :profile => profile.identifier
    assert_tag :tag => 'a', :attributes => {:href => "/myprofile/#{profile.identifier}/cms/publish/#{a.id}"}
  end

  should "display 'Publish' when profile is a community" do
    community = fast_create(Community)
    community.add_member(profile)
    Environment.any_instance.stubs(:portal_community).returns(community)
    a = fast_create(TextileArticle, :profile_id => community.id, :updated_at => DateTime.now)
    Article.stubs(:short_description).returns('bli')
    get :index, :profile => community.identifier
    assert_tag :tag => 'a', :attributes => {:href => "/myprofile/#{community.identifier}/cms/publish_on_portal_community/#{a.id}"}
  end

  should "not display 'Publish' when profile is not a person nor a community" do
    p = Community.create!(:name => 'community-test')
    p.add_admin(profile)
    a = p.articles.create!(:name => 'my new home page')
    Article.stubs(:short_description).returns('bli')
    get :index, :profile => p.identifier
    assert_no_tag :tag => 'a', :attributes => {:href => "/myprofile/#{p.identifier}/cms/publish/#{a.id}"}
  end

  should 'not offer to upload files to blog' do
    profile.articles << Blog.new(:name => 'blog test', :profile => profile)

    profile.articles.reload
    assert profile.has_blog?

    get :view, :profile => profile.identifier, :id => profile.blog.id
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/upload_files?parent_id=#{profile.blog.id}"}
  end

  should 'not allow user without permission create an article in community' do
    c = Community.create!(:name => 'test_comm', :identifier => 'test_comm')
    u = create_user_with_permission('test_user', 'bogus_permission', c)
    login_as :test_user

    get :new, :profile => c.identifier
    assert_response :forbidden
    assert_template 'access_denied.rhtml'
  end

  should 'allow user with permission create an article in community' do
    c = Community.create!(:name => 'test_comm', :identifier => 'test_comm')
    u = create_user_with_permission('test_user', 'publish_content', c)
    login_as :test_user
    @controller.stubs(:user).returns(u)

    get :new, :profile => c.identifier, :type => 'TinyMceArticle'
    assert_response :success
    assert_template 'edit'
  end

  should 'not allow user edit article if he has publish permission but is not owner' do
    c = Community.create!(:name => 'test_comm', :identifier => 'test_comm')
    u = create_user_with_permission('test_user', 'publish_content', c)
    a = c.articles.create!(:name => 'test_article')
    login_as :test_user

    get :edit, :profile => c.identifier, :id => a.id
    assert_response :forbidden
    assert_template 'access_denied.rhtml'
  end

  should 'not allow user edit article if he is owner but has no publish permission' do
    c = Community.create!(:name => 'test_comm', :identifier => 'test_comm')
    u = create_user_with_permission('test_user', 'bogus_permission', c)
    a = c.articles.create!(:name => 'test_article', :last_changed_by => u)
    login_as :test_user

    get :edit, :profile => c.identifier, :id => a.id
    assert_response :forbidden
    assert_template 'access_denied.rhtml'
  end

  should 'allow user edit article if he is owner and has publish permission' do
    c = Community.create!(:name => 'test_comm', :identifier => 'test_comm')
    u = create_user_with_permission('test_user', 'publish_content', c)
    a = c.articles.create!(:name => 'test_article', :last_changed_by => u)
    login_as :test_user
    @controller.stubs(:user).returns(u)

    get :edit, :profile => c.identifier, :id => a.id

    assert_response :success
    assert_template 'edit'
  end

  should 'create thumbnails for images with delayed_job' do
    post :upload_files, :profile => profile.identifier, :uploaded_files => [fixture_file_upload('/files/rails.png', 'image/png'), fixture_file_upload('/files/test.txt', 'text/plain')]
    file_1 = profile.articles.find_by_path('rails.png')
    file_2 = profile.articles.find_by_path('test.txt')

    process_delayed_job_queue

    UploadedFile.attachment_options[:thumbnails].each do |suffix, size|
      assert File.exists?(UploadedFile.find(file_1.id).public_filename(suffix))
      assert !File.exists?(UploadedFile.find(file_2.id).public_filename(suffix))
    end
    file_1.destroy
    file_2.destroy
  end

  # Forum

  should 'display posts per page input with default value on edit forum' do
    n = Forum.new.posts_per_page.to_s
    get :new, :profile => profile.identifier, :type => 'Forum'
    assert_tag :tag => 'select', :attributes => { :name => 'article[posts_per_page]' }, :child => { :tag => 'option', :attributes => {:value => n, :selected => 'selected'} }
  end

  should 'offer to edit a forum' do
    profile.articles << Forum.new(:name => 'forum test', :profile => profile)

    profile.articles.reload
    assert profile.has_forum?

    b = profile.forum
    get :index, :profile => profile.identifier
    assert_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/edit/#{b.id}"}
  end

  should 'not offer to add folder to forum' do
    profile.articles << Forum.new(:name => 'forum test', :profile => profile)

    profile.articles.reload
    assert profile.has_forum?

    get :view, :profile => profile.identifier, :id => profile.forum.id
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/new?parent_id=#{profile.forum.id}&amp;type=Folder"}
  end

  should 'not show feed subitem for forum' do
    profile.articles << Forum.new(:name => 'Forum for test', :profile => profile)

    profile.articles.reload
    assert profile.has_forum?

    get :view, :profile => profile.identifier, :id => profile.forum.id

    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/edit/#{profile.forum.feed.id}" }
  end

  should 'update feed options by edit forum form' do
    profile.articles << Forum.new(:name => 'Forum for test', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.forum.id, :article => { :feed => { :limit => 7 } }
    assert_equal 7, profile.forum.feed.limit
  end

  should 'not offer folder to forum articles' do
    @controller.stubs(:profile).returns(fast_create(Enterprise, :name => 'test_ent', :identifier => 'test_ent'))
    forum = Forum.create!(:name => 'Forum for test', :profile => profile)
    @controller.stubs(:params).returns({ :parent_id => forum.id })

    assert_not_includes @controller.available_article_types, Folder
  end

  should 'not offer rssfeed to forum articles' do
    @controller.stubs(:profile).returns(fast_create(Enterprise, :name => 'test_ent', :identifier => 'test_ent'))
    forum = Forum.create!(:name => 'Forum for test', :profile => profile)
    @controller.stubs(:params).returns({ :parent_id => forum.id })

    assert_not_includes @controller.available_article_types, RssFeed
  end

  should 'update forum posts_per_page setting' do
    profile.articles << Forum.new(:name => 'Forum for test', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.forum.id, :article => { :posts_per_page => 5 }
    profile.forum.reload
    assert_equal 5, profile.forum.posts_per_page
  end

  should 'go to forum after create it' do
    assert_difference Forum, :count do
      post :new, :type => Forum.name, :profile => profile.identifier, :article => { :name => 'my-forum' }, :back_to => 'control_panel'
    end
    assert_redirected_to @profile.articles.find_by_name('my-forum').view_url
  end

  should 'back to forum after config forum' do
    profile.articles << Forum.new(:name => 'my-forum', :profile => profile)
    post :edit, :profile => profile.identifier, :id => profile.forum.id

    assert_redirected_to @profile.articles.find_by_name('my-forum').view_url
  end

  should 'back to control panel if cancel create forum' do
    get :new, :profile => profile.identifier, :type => Forum.name
    assert_tag :tag => 'a', :content => 'Cancel', :attributes => { :href => /\/myprofile\/#{profile.identifier}/ }
  end

  should 'back to control panel if cancel config forum' do
    profile.articles << Forum.new(:name => 'my-forum', :profile => profile)
    get :edit, :profile => profile.identifier, :id => profile.forum.id
    assert_tag :tag => 'a', :content => 'Cancel', :attributes => { :href => /\/myprofile\/#{profile.identifier}/ }
  end

  should 'not offer to upload files to forum' do
    profile.articles << Forum.new(:name => 'forum test', :profile => profile)

    profile.articles.reload
    assert profile.has_forum?

    get :view, :profile => profile.identifier, :id => profile.forum.id
    assert_no_tag :tag => 'a', :attributes => { :href => "/myprofile/#{profile.identifier}/cms/upload_files?parent_id=#{profile.forum.id}"}
  end

  should 'not logged in to suggest an article' do
    logout
    get :suggest_an_article, :profile => profile.identifier, :back_to => 'action_view'

    assert_template 'suggest_an_article'
  end

  should 'render TinyMce Editor on suggestion of article' do
    logout
    get :suggest_an_article, :profile => profile.identifier

    assert_tag :tag => 'textarea', :attributes => { :name => /article_abstract/, :class => 'mceEditor' }
    assert_tag :tag => 'textarea', :attributes => { :name => /article_body/, :class => 'mceEditor' }
  end

  should 'create a task suggest task to a profile' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm', :moderated_articles => true)

    assert_difference SuggestArticle, :count do
      post :suggest_an_article, :profile => c.identifier, :back_to => 'action_view', :task => {:article_name => 'some name', :article_body => 'some body', :email => 'some@localhost.com', :name => 'some name'}
    end
  end

  should 'suggest an article from a profile' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm', :moderated_articles => true)
    get :suggest_an_article, :profile => c.identifier, :back_to => c.identifier
    assert_response :success
    assert_template 'suggest_an_article'
    assert_tag :tag => 'input', :attributes => { :value => c.identifier, :id => 'back_to' }
  end

  should 'suggest an article accessing the url directly' do
    c = Community.create!(:name => 'test comm', :identifier => 'test_comm', :moderated_articles => true)
    get :suggest_an_article, :profile => c.identifier
    assert_response :success
  end

  should 'article language should be selected' do
    textile = fast_create(TextileArticle, :profile_id => @profile.id, :path => 'textile', :language => 'ru')
    get :edit, :profile => @profile.identifier, :id => textile.id
    assert_tag :option, :attributes => { :selected => 'selected', :value => 'ru' }, :parent => {
      :tag => 'select', :attributes => { :id => 'article_language'} }
  end

  should 'list possible languages and include blank option' do
    get :new, :profile => @profile.identifier, :type => 'TextileArticle'
    assert_equal Noosfero.locales.invert, assigns(:locales)
    assert_tag :option, :attributes => { :value => '' }, :parent => {
      :tag => 'select', :attributes => { :id => 'article_language'} }
  end

  should 'add translation to an article' do
    textile = fast_create(TextileArticle, :profile_id => @profile.id, :path => 'textile', :language => 'ru')
    assert_difference Article, :count do
      post :new, :profile => @profile.identifier, :type => 'TextileArticle', :article => { :name => 'english translation', :translation_of_id => textile.id, :language => 'en' }
    end
  end

  should 'not display language selection if article is not translatable' do
    blog = fast_create(Blog, :name => 'blog', :profile_id => @profile.id)
    get :edit, :profile => @profile.identifier, :id => blog.id
    assert_no_tag :select, :attributes => { :id => 'article_language'}
  end

  should 'display display posts in current language input checked on edit blog' do
    get :new, :profile => profile.identifier, :type => 'Blog'
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[display_posts_in_current_language]', :checked => 'checked' }
  end

  should 'update to false blog display posts in current language setting' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile, :display_posts_in_current_language => true)
    post :edit, :profile => profile.identifier, :id => profile.blog.id, :article => { :display_posts_in_current_language => false }
    profile.blog.reload
    assert !profile.blog.display_posts_in_current_language?
  end

  should 'update to true blog display posts in current language setting' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile, :display_posts_in_current_language => false)
    post :edit, :profile => profile.identifier, :id => profile.blog.id, :article => { :display_posts_in_current_language => true }
    profile.blog.reload
    assert profile.blog.display_posts_in_current_language?
  end

  should 'be checked display posts in current language checkbox' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile, :display_posts_in_current_language => true)
    get :edit, :profile => profile.identifier, :id => profile.blog.id
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[display_posts_in_current_language]', :checked => 'checked' }
  end

  should 'be unchecked display posts in current language checkbox' do
    profile.articles << Blog.new(:name => 'Blog for test', :profile => profile, :display_posts_in_current_language => false)
    get :edit, :profile => profile.identifier, :id => profile.blog.id
    assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[display_posts_in_current_language]' }
    assert_no_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => 'article[display_posts_in_current_language]', :checked => 'checked' }
  end

  should 'not display accept comments option when creating forum post' do
    profile.articles << f = Forum.new(:name => 'Forum for test')
    get :new, :profile => profile.identifier, :type => 'TinyMceArticle', :parent_id => f.id
    assert :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'hidden'}
    assert_no_tag :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'checkbox'}
  end

  should 'display accept comments option when creating an article that is not a forum post' do
    get :new, :profile => profile.identifier, :type => 'TinyMceArticle'
    assert_no_tag :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'hidden'}
    assert_tag :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'checkbox'}
  end

  should 'display accept comments option when editing forum post' do
    profile.articles << f = Forum.new(:name => 'Forum for test')
    profile.articles << a = TinyMceArticle.new(:name => 'Forum post for test', :parent => f)
    get :edit, :profile => profile.identifier, :id => a.id
    assert_no_tag :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'hidden'}
    assert_tag :tag => 'input', :attributes => {:name => 'article[accept_comments]', :value => 1, :type => 'checkbox'}
  end

  should 'display accept comments option when editing forum post with a different label' do
    profile.articles << f = Forum.new(:name => 'Forum for test')
    profile.articles << a = TinyMceArticle.new(:name => 'Forum post for test', :parent => f)
    get :edit, :profile => profile.identifier, :id => a.id
    assert_tag :tag => 'label', :attributes => { :for => 'article_accept_comments' }, :content => _('This topic is opened for replies')
  end

  should 'display correct label for accept comments option for an article that is not a forum post' do
    profile.articles << a = TinyMceArticle.new(:name => 'Forum post for test')
    get :edit, :profile => profile.identifier, :id => a.id
    assert_tag :tag => 'label', :attributes => { :for => 'article_accept_comments' }, :content => _('I want to receive comments about this article')
  end

  should 'display filename if uploaded file has not title' do
    file = UploadedFile.create!(:uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'), :profile => @profile)
    get :index, :profile => @profile.identifier
    assert_tag :a, :content => "rails.png"
  end

  should 'display title if uploaded file has one' do
    file = UploadedFile.create!(:uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'), :profile => @profile, :title => 'An image')
    get :index, :profile => @profile.identifier
    assert_tag :a, :content => "An image"
  end

  should 'update image and be redirect to view_page' do
    image = UploadedFile.create!(:profile => @profile, :uploaded_data => fixture_file_upload('files/rails.png', 'image/png'))
    post :edit, :profile => @profile.identifier, :id => image.id, :article => { }
    assert_redirected_to image.view_url
  end

  should 'update article and be redirect to view_page' do
    a = fast_create(TextileArticle, :profile_id => @profile.id)
    post :edit, :profile => @profile.identifier, :id => a.id, :article => { }
    assert_redirected_to a.view_url
  end

  should 'update file and be redirect to cms' do
    file = UploadedFile.create!(:profile => @profile, :uploaded_data => fixture_file_upload('files/test.txt', 'text/plain'))
    post :edit, :profile => @profile.identifier, :id => file.id, :article => { }
    assert_redirected_to :action => 'index'
  end

  should 'update file and be redirect to cms folder' do
    f = fast_create(Folder, :profile_id => @profile.id, :name => 'foldername')
    file = UploadedFile.create!(:profile => @profile, :uploaded_data => fixture_file_upload('files/test.txt', 'text/plain'), :parent_id => f.id)
    post :edit, :profile => @profile.identifier, :id => file.id, :article => { :title => 'text file' }
    assert_redirected_to :action => 'view', :id => f
  end

  should 'render TinyMce Editor for events' do
    get :new, :profile => @profile.identifier, :type => 'Event'
    assert_tag :tag => 'textarea', :attributes => { :class => 'mceEditor' }
  end

  should 'identify form with classname of edited article' do
    [Blog, TinyMceArticle, Forum].each do |klass|
      a = fast_create(klass, :profile_id => profile.id)
      get :edit, :profile => profile.identifier, :id => a.id
      assert_tag :tag => 'form', :attributes => {:class => klass.to_s}
    end
  end

  should 'search for content for inclusion in articles' do
    file = UploadedFile.create!(:profile => @profile, :uploaded_data => fixture_file_upload('files/test.txt', 'text/plain'))
    get :search, :profile => @profile.identifier, :q => 'test.txt'
    assert_match /test.txt/, @response.body
    assert_equal 'application/json', @response.content_type

    data = parse_json_response
    assert_equal 'test.txt', data.first['title']
    assert_match /\/testinguser\/test.txt$/, data.first['url']
    assert_match /text/, data.first['icon']
    assert_match /text/, data.first['content_type']
  end

  should 'upload media by AJAX' do
    post :media_upload, :profile => profile.identifier, :file1 => fixture_file_upload('/files/test.txt', 'text/plain'), :file2 => fixture_file_upload('/files/rails.png', 'image/png'), :file3 => ''
    assert_match 'test.txt', @response.body
    assert_equal 'text/plain', @response.content_type

    data = parse_json_response

    assert_equal 'test.txt', data[0]['title']
    assert_match /\/testinguser\/test.txt$/, data[0]['url']
    assert_match /text/, data[0]['icon']
    assert_match /text/, data[0]['content_type']
    assert_nil data[0]['error']

    assert_equal 'rails.png', data[1]['title']
    assert_no_match /\/public\/articles\/.*\/rails.png$/, data[1]['url']
    assert_match /png$/, data[1]['icon']
    assert_match /image/, data[1]['content_type']
    assert_nil data[1]['error']

  end

  should 'not when media upload via AJAX contains empty files' do
    post :media_upload, :profile => @profile.identifier
  end

  should 'mark unsuccessfull uploads' do
    file = UploadedFile.create!(:profile => profile, :uploaded_data => fixture_file_upload('files/rails.png', 'image/png'))

    post :media_upload, :profile => profile.identifier, :media_listing => true, :file1 => fixture_file_upload('files/rails.png', 'image/png'), :file2 => fixture_file_upload('/files/test.txt', 'text/plain')

    assert_equal 'text/plain', @response.content_type
    data = parse_json_response

    assert_equal 'rails.png', data[0]['title']
    assert_not_nil data[0]['error']
    assert_match /rails.png/, data[0]['error']

    assert_equal 'test.txt', data[1]['title']
    assert_nil data[1]['error']
  end

  protected

  # FIXME this is to avoid adding an extra dependency for a proper JSON parser.
  # For now we are assuming that the JSON is close enough to Ruby and just
  # making some adjustments.
  def parse_json_response
    eval(@response.body.gsub('":', '"=>').gsub('null', 'nil'))
  end

  should 'make RawHTMLArticle available only to environment admins' do
    @controller.stubs(:profile).returns(profile)
    assert_not_includes @controller.available_article_types, RawHTMLArticle
    profile.environment.add_admin(profile)
    assert_includes @controller.available_article_types, RawHTMLArticle
  end

end
