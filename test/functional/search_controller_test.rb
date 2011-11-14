require File.dirname(__FILE__) + '/../test_helper'
require 'search_controller'

# Re-raise errors caught by the controller.
class SearchController; def rescue_action(e) raise e end; end

class SearchControllerTest < Test::Unit::TestCase
  def setup
    @controller = SearchController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @category = Category.create!(:name => 'my category', :environment => Environment.default)

    domain = Environment.default.domains.first
    domain.google_maps_key = 'ENVIRONMENT_KEY'
    domain.save!

    @product_category = fast_create(ProductCategory)
  end

  def create_article_with_optional_category(name, profile, category = nil)
    fast_create(Article, {:name => name, :profile_id => profile.id }, :search => true, :category => category)
  end

  def create_profile_with_optional_category(klass, name, category = nil, data = {})
    fast_create(klass, { :name => name }.merge(data), :search => true, :category => category)
  end

  def test_local_files_reference
    assert_local_files_reference
  end

  def test_valid_xhtml
    assert_valid_xhtml
  end

  should 'filter stop words' do
    @controller.expects(:locale).returns('pt_BR').at_least_once
    get 'index', :query => 'a carne da vaca'
    assert_response :success
    assert_template 'index'
    assert_equal 'carne vaca', assigns('filtered_query')
  end

  should 'search with filtered query' do
    @controller.expects(:locale).returns('pt_BR').at_least_once
    get 'index', :query => 'a carne da vaca'

    assert_equal 'carne vaca', assigns('filtered_query')
  end

  should 'espape xss attack' do
    get 'index', :query => '<wslite>'
    assert_no_tag :tag => 'wslite'
  end

  should 'search only in specified types of content' do
    get :index, :query => 'something not important', :find_in => [ 'articles' ]
    assert_equal [:articles], assigns(:results).keys
  end

  should 'search in more than one specified types of content' do
    get :index, :query => 'something not important', :find_in => [ 'articles', 'people' ]
    assert_equivalent [:articles, :people ], assigns(:results).keys
  end

  should 'render success in search' do
    get :index, :query => 'something not important'
    assert_response :success
  end

  should 'search for articles' do
    person = fast_create(Person)
    art = create_article_with_optional_category('an article to be found', person)

    get 'index', :query => 'article found', :find_in => [ 'articles' ]
    assert_includes assigns(:results)[:articles], art
  end

  should 'search for articles in a specific category' do
    person = fast_create(Person)

    # in category
    art1 = create_article_with_optional_category('an article to be found', person, @category)
    # not in category
    art2 = create_article_with_optional_category('another article to be found', person)

    get :index, :category_path => [ 'my-category' ], :query => 'article found', :find_in => [ 'articles' ]

    assert_includes assigns(:results)[:articles], art1
    assert_not_includes assigns(:results)[:articles], art2
  end

  # 'assets' outside any category
  should 'list articles in general' do
    person = fast_create(Person)

    art1 = create_article_with_optional_category('one article', person, @category)
    art2 = create_article_with_optional_category('two article', person, @category)

    get :assets, :asset => 'articles'

    assert_includes assigns(:results)[:articles], art1
    assert_includes assigns(:results)[:articles], art2
  end

  # 'assets' inside a category
  should 'list articles in a specific category' do
    person = fast_create(Person)

    # in category
    art1 = create_article_with_optional_category('one article', person, @category)
    art2 = create_article_with_optional_category('two article', person, @category)
    # not in category
    art3 = create_article_with_optional_category('another article', person)

    get :assets, :asset => 'articles', :category_path => ['my-category']

    assert_includes assigns(:results)[:articles], art1
    assert_includes assigns(:results)[:articles], art2
    assert_not_includes assigns(:results)[:articles], art3
  end

  should 'find enterprises' do
    ent = create_profile_with_optional_category(Enterprise, 'teste')
    get 'index', :query => 'teste', :find_in => [ 'enterprises' ]
    assert_includes assigns(:results)[:enterprises], ent
  end

  should 'find enterprises in a specified category' do

    # in category
    ent1 = create_profile_with_optional_category(Enterprise, 'testing enterprise 1', @category)
    # not in category
    ent2 = create_profile_with_optional_category(Enterprise, 'testing enterprise 2')

    get :index, :category_path => [ 'my-category' ], :query => 'testing', :find_in => [ 'enterprises' ]

    assert_includes assigns(:results)[:enterprises], ent1
    assert_not_includes assigns(:results)[:enterprises], ent2
  end

  should 'list enterprises in general' do
    ent1 = create_profile_with_optional_category(Enterprise, 'teste 1')
    ent2 = create_profile_with_optional_category(Enterprise, 'teste 2')

    get :assets, :asset => 'enterprises'
    assert_includes assigns(:results)[:enterprises], ent1
    assert_includes assigns(:results)[:enterprises], ent2
  end

  # 'assets' menu inside a category
  should 'list enterprises in a specified category' do
    # in category
    ent1 = create_profile_with_optional_category(Enterprise, 'teste 1', @category)
    # not in category
    ent2 = create_profile_with_optional_category(Enterprise, 'teste 2')

    get :assets, :asset => 'enterprises', :category_path => [ 'my-category' ]
    assert_includes assigns(:results)[:enterprises], ent1
    assert_not_includes assigns(:results)[:enterprises], ent2
  end

  should 'find people' do
    p1 = create_user('people_1').person; p1.name = 'a beautiful person'; p1.save!
    get :index, :query => 'beautiful', :find_in => [ 'people' ]
    assert_includes assigns(:results)[:people], p1
  end

  should 'find people in a specific category' do
    p1 = create_user('people_1').person; p1.name = 'a beautiful person'; p1.add_category @category; p1.save!
    p2 = create_user('people_2').person; p2.name = 'another beautiful person'; p2.save!
    get :index, :category_path => [ 'my-category' ], :query => 'beautiful', :find_in => [ 'people' ]
    assert_includes assigns(:results)[:people], p1
    assert_not_includes assigns(:results)[:people], p2
  end

  # 'assets' menu outside any category
  should 'list people in general' do
    Profile.delete_all

    p1 = create_user('test1').person
    p2 = create_user('test2').person

    get :assets, :asset => 'people'

    assert_equivalent [p2,p1], assigns(:results)[:people]
  end

  # 'assets' menu inside a category
  should 'list people in a specified category' do
    Profile.delete_all

    # in category
    p1 = create_user('test1').person; p1.add_category @category

    # not in category
    p2 = create_user('test2').person

    get :assets, :asset => 'people', :category_path => [ 'my-category' ]
    assert_equal [p1], assigns(:results)[:people]
  end

  should 'find communities' do
    c1 = create_profile_with_optional_category(Community, 'a beautiful community')
    get :index, :query => 'beautiful', :find_in => [ 'communities' ]
    assert_includes assigns(:results)[:communities], c1
  end

  should 'find communities in a specified category' do
    c1 = create_profile_with_optional_category(Community, 'a beautiful community', @category)
    c2 = create_profile_with_optional_category(Community, 'another beautiful community')
    get :index, :category_path => [ 'my-category' ], :query => 'beautiful', :find_in => [ 'communities' ]
    assert_includes assigns(:results)[:communities], c1
    assert_not_includes assigns(:results)[:communities], c2
  end

  # 'assets' menu outside any category
  should 'list communities in general' do
    c1 = create_profile_with_optional_category(Community, 'a beautiful community')
    c2 = create_profile_with_optional_category(Community, 'another beautiful community')

    get :assets, :asset => 'communities'
    assert_equivalent [c2, c1], assigns(:results)[:communities]
  end

  # 'assets' menu
  should 'list communities in a specified category' do

    # in category
    c1 = create_profile_with_optional_category(Community, 'a beautiful community', @category)

    # not in category
    c2 = create_profile_with_optional_category(Community, 'another beautiful community')

    # in category
    c3 = create_profile_with_optional_category(Community, 'yet another beautiful community', @category)

    get :assets, :asset => 'communities', :category_path => [ 'my-category' ]

    assert_equivalent [c3, c1], assigns(:results)[:communities]
  end

  should 'find products' do
    ent = create_profile_with_optional_category(Enterprise, 'teste')
    prod = ent.products.create!(:name => 'a beautiful product', :product_category => @product_category)
    get 'index', :query => 'beautiful', :find_in => ['products']
    assert_includes assigns(:results)[:products], prod
  end

  should 'find products in a specific category' do
    ent1 = create_profile_with_optional_category(Enterprise, 'teste1', @category)
    ent2 = create_profile_with_optional_category(Enterprise, 'teste2')
    prod1 = ent1.products.create!(:name => 'a beautiful product', :product_category => @product_category)
    prod2 = ent2.products.create!(:name => 'another beautiful product', :product_category => @product_category)
    get :index, :category_path => @category.path.split('/'), :query => 'beautiful', :find_in => ['products']
    assert_includes assigns(:results)[:products], prod1
    assert_not_includes assigns(:results)[:products], prod2
  end

  # 'assets' menu outside any category
  should 'list products in general' do
    Profile.delete_all

    ent1 = create_profile_with_optional_category(Enterprise, 'teste1')
    ent2 = create_profile_with_optional_category(Enterprise, 'teste2')
    prod1 = ent1.products.create!(:name => 'a beautiful product', :product_category => @product_category)
    prod2 = ent2.products.create!(:name => 'another beautiful product', :product_category => @product_category)

    get :assets, :asset => 'products'
    assert_equivalent [prod2, prod1], assigns(:results)[:products]
  end

  # 'assets' menu inside a category
  should 'list products in a specific category' do
    Profile.delete_all

    # in category
    ent1 = create_profile_with_optional_category(Enterprise, 'teste1', @category)
    prod1 = ent1.products.create!(:name => 'a beautiful product', :product_category => @product_category)

    # not in category
    ent2 = create_profile_with_optional_category(Enterprise, 'teste2')
    prod2 = ent2.products.create!(:name => 'another beautiful product', :product_category => @product_category)

    get :assets, :asset => 'products', :category_path => [ 'my-category' ]

    assert_equal [prod1], assigns(:results)[:products]
  end

  should 'include extra content supplied by plugins on product asset' do
    class Plugin1 < Noosfero::Plugin
      def asset_product_extras(product, enterprise)
        lambda {"<span id='plugin1'>This is Plugin1 speaking!</span>"}
      end
    end
  
    class Plugin2 < Noosfero::Plugin
      def asset_product_extras(product, enterprise)
        lambda {"<span id='plugin2'>This is Plugin2 speaking!</span>"}
      end
    end
  
    enterprise = fast_create(Enterprise)
    product = fast_create(Product, :enterprise_id => enterprise.id)

    e = Environment.default
    e.enable_plugin(Plugin1.name)
    e.enable_plugin(Plugin2.name)

    get :assets, :asset => 'products'

    assert_tag :tag => 'span', :content => 'This is Plugin1 speaking!', :attributes => {:id => 'plugin1'}
    assert_tag :tag => 'span', :content => 'This is Plugin2 speaking!', :attributes => {:id => 'plugin2'}
  end

  should 'include extra properties of the product supplied by plugins' do
    class Plugin1 < Noosfero::Plugin
      def asset_product_properties(product)
        return { :name => _('Property1'), :content => lambda { link_to(product.name, '/plugin1') } }
      end
    end
    class Plugin2 < Noosfero::Plugin
      def asset_product_properties(product)
        return { :name => _('Property2'), :content => lambda { link_to(product.name, '/plugin2') } }
      end
    end
    enterprise = fast_create(Enterprise)
    product = fast_create(Product, :enterprise_id => enterprise.id)

    environment = Environment.default
    environment.enable_plugin(Plugin1.name)
    environment.enable_plugin(Plugin2.name)

    get :assets, :asset => 'products'

    assert_tag :tag => 'li', :content => /Property1/, :child => {:tag => 'a', :attributes => {:href => '/plugin1'}, :content => product.name}
    assert_tag :tag => 'li', :content => /Property2/, :child => {:tag => 'a', :attributes => {:href => '/plugin2'}, :content => product.name}
  end

  should 'paginate enterprise listing' do
    @controller.expects(:limit).returns(1)
    ent1 = create_profile_with_optional_category(Enterprise, 'teste 1')
    ent2 = create_profile_with_optional_category(Enterprise, 'teste 2')

    get :assets, :asset => 'enterprises', :page => '2'

    assert_equal 1, assigns(:results)[:enterprises].size
  end

  should 'display search results' do
    ent = create_profile_with_optional_category(Enterprise, 'display enterprise')
    product = ent.products.create!(:name => 'display product', :product_category => @product_category)
    person = create_user('displayperson').person; person.name = 'display person'; person.save!
    article = person.articles.create!(:name => 'display article')
    event = Event.new(:name => 'display event', :start_date => Date.today); event.profile = person; event.save!
    comment = article.comments.create!(:title => 'display comment', :body => '...', :author => person)
    community = create_profile_with_optional_category(Community, 'display community')

    get :index, :query => 'display'

    names = {
        :articles => ['Articles', article],
        :enterprises => ['Enterprises', ent],
        :communities => ['Communities', community],
        :products => ['Products', product],
        :events => ['Events', event],
    }
    names.each do |thing, pair|
      description, object = pair
      assert_tag :tag => 'div', :attributes => { :class => /search-results-#{thing}/ }, :descendant => { :tag => 'h3', :content => Regexp.new(description) }
      assert_tag :tag => 'a', :content => object.respond_to?(:short_name) ? object.short_name : object.name
    end

    # display only first name on people listing
    assert_tag :tag => 'div', :attributes => { :class => /search-results-people/ }, :descendant => { :tag => 'h3', :content => /People/ }
  end

  should 'present options of where to search' do
    get :popup
    names = {
        :articles => 'Articles',
        :people => 'People',
        :enterprises => 'Enterprises',
        :communities => 'Communities',
        :products => 'Products',
        :events => 'Events',
    }
    names.each do |thing,description|
      assert_tag :tag => 'input', :attributes => { :type => 'checkbox', :name => "find_in[]", :value => thing.to_s, :checked => 'checked' }
      assert_tag :tag => 'label', :content => description
    end
  end

  should 'not display option to choose where to search when not inside filter' do
    get :popup
    assert_no_tag :tag => 'input', :attributes => { :type => 'radio', :name => 'search_whole_site', :value => 'yes' }
  end

  should 'display option to choose searching in whole site or in current category' do
    parent = Category.create!(:name => 'cat', :environment => Environment.default)
    Category.create!(:name => 'sub', :environment => Environment.default, :parent => parent)

    get :popup, :category_path => [ 'cat', 'sub']
    assert_tag :tag => 'input', :attributes => { :type => 'submit', :name => 'search_whole_site_yes' }
    assert_tag :tag => 'input', :attributes => { :type => 'submit', :name => 'search_whole_site_no' }
  end

  should 'display option to search within a given point and distance' do
    state = State.create!(:name => "Bahia", :environment => Environment.default)
    get :popup

    assert_tag :tag => 'select', :attributes => {:name => 'radius'}
    assert_tag :tag => 'select', :attributes => {:name => 'state'}
    assert_tag :tag => 'select', :attributes => {:name => 'city'}
  end

  should 'search in whole site when told so' do
    parent = Category.create!(:name => 'randomcat', :environment => Environment.default)
    Category.create!(:name => 'randomchild', :environment => Environment.default, :parent => parent)

    get :index, :category_path => [ 'randomcat', 'randomchild' ], :query => 'some random query', :search_whole_site => 'yes'

    # search_whole_site must be removed to precent a infinite redirect loop
    assert_redirected_to :action => 'index', :category_path => [], :query => 'some random query', :search_whole_site => nil
  end

  should 'submit form to root when not inside a filter' do
    get :popup
    assert_tag :tag => 'form', :attributes => { :action => '/search' }
  end

  should 'submit form to category path when inside a filter' do
    get :popup, :category_path => Category.create!(:name => 'mycat', :environment => Environment.default).explode_path
    assert_tag :tag => 'form', :attributes => { :action => '/search/index/mycat' }
  end

  should 'use GET method to search' do
    get :popup
    assert_tag :tag => 'form' , :attributes => { :method => 'get' }
  end

  should 'display a given category' do
    get :category_index, :category_path => [ 'my-category' ]
    assert_equal @category, assigns(:category)
  end

  should 'expose category in a method' do
    get :category_index, :category_path => [ 'my-category' ]
    assert_same assigns(:category), @controller.category
  end

  should 'list recent articles in the category' do
    recent = []
    finger = CategoryFinder.new(@category)
    finger.expects(:recent).with(any_parameters).at_least_once
    finger.expects(:recent).with('text_articles', anything).returns(recent)
    CategoryFinder.expects(:new).with(@category).returns(finger)

    get :category_index, :category_path => [ 'my-category' ]
    assert_same recent, assigns(:results)[:articles]
  end

  should 'list most commented articles in the category' do
    most_commented = []
    finger = CategoryFinder.new(@category)
    finger.expects(:most_commented_articles).returns(most_commented)
    CategoryFinder.expects(:new).with(@category).returns(finger)

    get :category_index, :category_path => [ 'my-category' ]
    assert_same most_commented, assigns(:results)[:most_commented_articles]
  end

  should 'list recently registered people in the category' do
    recent_people = []
    finger = CategoryFinder.new(@category)
    finger.expects(:recent).with(any_parameters).at_least_once
    finger.expects(:recent).with('people', kind_of(Integer)).returns(recent_people)
    CategoryFinder.expects(:new).with(@category).returns(finger)

    get :category_index, :category_path => [ 'my-category' ]
    assert_same recent_people, assigns(:results)[:people]
  end

  should 'list recently registered communities in the category' do
    recent_communities = []
    finger = CategoryFinder.new(@category)
    finger.expects(:recent).with(any_parameters).at_least_once
    finger.expects(:recent).with('communities', anything).returns(recent_communities)
    CategoryFinder.expects(:new).with(@category).returns(finger)

    get :category_index, :category_path => [ 'my-category' ]
    assert_same recent_communities, assigns(:results)[:communities]
  end

  should 'list recently registered enterprises in the category' do
    recent_enterptises = []
    finger = CategoryFinder.new(@category)
    finger.expects(:recent).with(any_parameters).at_least_once
    finger.expects(:recent).with('enterprises', anything).returns(recent_enterptises)
    CategoryFinder.expects(:new).with(@category).returns(finger)

    get :category_index, :category_path => [ 'my-category' ]
    assert_same recent_enterptises, assigns(:results)[:enterprises]
  end

  should 'not list "Search for ..." in category_index' do
    get :category_index, :category_path => [ 'my-category' ]
    assert_no_tag :content => /Search for ".*" in the whole site/
  end

  # SECURITY
  should 'not allow unrecognized assets' do
    get :assets, :asset => 'unexisting_asset'
    assert_response 403
  end

  should 'not use design blocks' do
    get :index
    assert_no_tag :tag => 'div', :attributes => { :id => 'boxes', :class => 'boxes' }
  end

  should 'offer text box to enter a new search in general context' do
    get :index, :query => 'a sample search'
    assert_tag :tag => 'form', :attributes => { :action => '/search' }, :descendant => {
      :tag => 'input',
      :attributes => { :name => 'query', :value => 'a sample search' }
    }
  end

  should 'offer text box to enter a new seach in specific context' do
    get :index, :category_path => [ 'my-category'], :query => 'a sample search'
    assert_tag :tag => 'form', :attributes => { :action => '/search/index/my-category' }, :descendant => {
      :tag => 'input',
      :attributes => { :name => 'query', :value => 'a sample search' }
    }
  end

  should 'offer button search in the whole site' do
    get :index, :category_path => [ 'my-category' ], :query => 'a sample search'
    assert_tag :tag => 'input', :attributes => { :type => 'submit', :name => 'search_whole_site_yes' }
  end

  should 'display only category name in "search results for ..." title' do
    parent = Category.create!(:name => 'Parent Category', :environment => Environment.default)
    child = Category.create!(:name => "Child Category", :environment => Environment.default, :parent => parent)

    get :index, :category_path => [ 'parent-category', 'child-category' ], :query => 'a sample search'
    assert_tag :tag => 'h2', :content => /Searched for 'a sample search'/
    assert_tag :tag => 'h2', :content => /In category Child Category/
  end

  should 'search in category hierachy' do
    parent = Category.create!(:name => 'Parent Category', :environment => Environment.default)
    child  = Category.create!(:name => 'Child Category', :environment => Environment.default, :parent => parent)

    p = create_profile_with_optional_category(Person, 'test_profile', child)

    get :index, :category_path => ['parent-category'], :query => 'test_profile', :find_in => ['people']

    assert_includes assigns(:results)[:people], p
  end

  # FIXME how do test link_to_remote?
  should 'keep asset selection for new searches' do
    get :index, :query => 'a sample query', :find_in => [ 'people', 'communities' ]
    assert_tag :tag => 'input', :attributes =>  { :name => 'find_in[]', :value => 'people', :checked => 'checked' }
    assert_tag :tag => 'input', :attributes =>  { :name => 'find_in[]', :value => 'communities', :checked => 'checked' }
    assert_no_tag :tag => 'input', :attributes =>  { :name => 'find_in[]', :value => 'enterprises', :checked => 'checked' }
    assert_no_tag :tag => 'input', :attributes =>  { :name => 'find_in[]', :value => 'products', :checked => 'checked' }
  end

  should 'find enterprise by product category' do
    ent1 = create_profile_with_optional_category(Enterprise, 'test1')
    prod_cat = ProductCategory.create!(:name => 'pctest', :environment => Environment.default)
    prod = ent1.products.create!(:name => 'teste', :product_category => prod_cat)

    ent2 = create_profile_with_optional_category(Enterprise, 'test2')

    get :index, :query => prod_cat.name

    assert_includes assigns('results')[:enterprises], ent1
    assert_not_includes assigns('results')[:enterprises], ent2
  end

  should 'find profiles by radius and region' do
    city = City.create!(:name => 'r-test', :environment => Environment.default, :lat => 45.0, :lng => 45.0)
    ent1 = create_profile_with_optional_category(Enterprise, 'test 1', nil, :lat => 45.0, :lng => 45.0)
    p1 = create_profile_with_optional_category(Person, 'test 2', nil, :lat => 45.0, :lng => 45.0)

    ent2 = create_profile_with_optional_category(Enterprise, 'test 1', nil, :lat => 30.0, :lng => 30.0)
    p2 = create_profile_with_optional_category(Person, 'test 2', nil, :lat => 30.0, :lng => 30.0)

    get :index, :city => city.id, :radius => 10, :query => 'test'

    assert_includes assigns('results')[:enterprises], ent1
    assert_not_includes assigns('results')[:enterprises], ent2
    assert_includes assigns('results')[:people], p1
    assert_not_includes assigns('results')[:people], p2
  end

  should 'display category image while in directory' do
    parent = Category.create!(:name => 'category1', :environment => Environment.default)
    cat = Category.create!(:name => 'category2', :environment => Environment.default, :parent => parent,
      :image_builder => {:uploaded_data => fixture_file_upload('/files/rails.png', 'image/png')}
    )

    process_delayed_job_queue
    get :category_index, :category_path => [ 'category1', 'category2' ], :query => 'teste'
    assert_tag :tag => 'img', :attributes => { :src => /rails_thumb\.png/ }
  end

  should 'complete region name' do
    r1 = Region.create!(:name => 'One region', :environment => Environment.default, :lat => 111.07, :lng => '88.9')
    r2 = Region.create!(:name => 'Another region', :environment => Environment.default, :lat => 111.07, :lng => '88.9')

    get :complete_region, :region => { :name => 'one' }
    assert_includes assigns(:regions), r1
    assert_tag :tag => 'ul', :descendant => { :tag => 'li', :content => 'One region' }
  end

  should 'render completion results without layout' do
    get :complete_region, :region => { :name => 'test' }
    assert_no_tag :tag => 'body'
  end

  should 'complete only georeferenced regions' do
    r1 = Region.create!(:name => 'One region', :environment => Environment.default, :lat => 111.07, :lng => '88.9')
    r2 = Region.create!(:name => 'Another region', :environment => Environment.default)

    get :complete_region, :region => { :name => 'region' }
    assert_includes assigns(:regions), r1
    assert_tag :tag => 'ul', :descendant => { :tag => 'li', :content => r1.name }
    assert_not_includes assigns(:regions), r2
    assert_no_tag :tag => 'ul', :descendant => { :tag => 'li', :content => r2.name }
  end
  
  should 'return options of cities by its state' do
    state1 = State.create!(:name => 'State One', :environment => Environment.default)
    state2 = State.create!(:name => 'State Two', :environment => Environment.default)
    city1 = City.create!(:name => 'City One', :environment => Environment.default, :lat => 111.07, :lng => '88.9', :parent => state1)
    city2 = City.create!(:name => 'City Two', :environment => Environment.default, :lat => 111.07, :lng => '88.9', :parent => state2)

    get :cities, :state_id => state1.id
    assert_includes assigns(:cities), city1
    assert_tag :tag => 'option', :content => city1.name, :attributes => {:value => city1.id}
    assert_not_includes assigns(:cities), city2
    assert_no_tag :tag => 'option', :content => city2.name, :attributes => {:value => city2.id}
  end

  should 'render cities results without layout' do
    get :cities, :state_id => 1
    assert_no_tag :tag => 'body'
  end

  should 'list only georeferenced cities' do
    state = State.create!(:name => 'State One', :environment => Environment.default)
    city1 = City.create!(:name => 'City One', :environment => Environment.default, :lat => 111.07, :lng => '88.9', :parent => state)
    city2 = City.create!(:name => 'City Two', :environment => Environment.default, :parent => state)

    get :cities, :state_id => state.id

    assert_includes assigns(:cities), city1
    assert_not_includes assigns(:cities), city2
  end

  should 'search for events' do
    person = create_user('teste').person
    ev = create_event(person, :name => 'an event to be found')

    get 'index', :query => 'event found', :find_in => [ 'events' ]

    assert_includes assigns(:results)[:events], ev
  end

  should 'search for events in a specific category' do
    person = create_user('teste').person

    # in category
    ev1 = create_event(person, :name => 'an event to be found')
    ev1.add_category @category
    ev1.save!

    # not in category
    ev2 = create_event(person, :name => 'another event to be found')
    ev2.save!

    get :index, :category_path => [ 'my-category' ], :query => 'event found', :find_in => [ 'events' ]

    assert_includes assigns(:results)[:events], ev1
    assert_not_includes assigns(:results)[:events], ev2
  end

  # 'assets' outside any category
  should 'list events in general' do
    person = create_user('testuser').person
    person2 = create_user('anotheruser').person

    ev1 = create_event(person, :name => 'one event', :category_ids => [@category.id])

    ev2 = create_event(person2, :name => 'two event', :category_ids => [@category.id])

    get :assets, :asset => 'events'

    assert_includes assigns(:results)[:events], ev1
    assert_includes assigns(:results)[:events], ev2
  end

  # 'assets' inside a category
  should 'list events in a specific category' do
    person = create_user('testuser').person

    # in category
    ev1 = create_event(person, :name => 'one event', :category_ids => [@category.id])
    ev2 = create_event(person, :name => 'other event', :category_ids => [@category.id])

    # not in category
    ev3 = create_event(person, :name => 'another event')

    get :assets, :asset => 'events', :category_path => ['my-category']

    assert_includes assigns(:results)[:events], ev1
    assert_includes assigns(:results)[:events], ev2
    assert_not_includes assigns(:results)[:events], ev3
  end

  should 'list events for a given month' do
    person = create_user('testuser').person

    create_event(person, :name => 'upcoming event 1', :category_ids => [@category.id], :start_date => Date.new(2008, 1, 25))
    create_event(person, :name => 'upcoming event 2', :category_ids => [@category.id], :start_date => Date.new(2008, 4, 27))

    get :assets, :asset => 'events', :year => '2008', :month => '1'

    assert_equal [ 'upcoming event 1' ], assigns(:results)[:events].map(&:name)
  end

  should 'list events for a given month in a specific category' do
    person = create_user('testuser').person

    create_event(person, :name => 'upcoming event 1', :category_ids => [@category.id], :start_date => Date.new(2008, 1, 25))
    create_event(person, :name => 'upcoming event 2', :category_ids => [@category.id], :start_date => Date.new(2008, 4, 27))

    get :assets, :asset => 'events', :category_path => [ 'my-category' ], :year => '2008', :month => '1'

    assert_equal [ 'upcoming event 1' ], assigns(:results)[:events].map(&:name)
  end

  should 'list upcoming events in a specific category' do
    person = create_user('testuser').person

    # today is January 15th, 2008
    Date.expects(:today).returns(Date.new(2008,1,15)).at_least_once

    # in category, but in the past
    create_event(person, :name => 'past event', :category_ids => [@category.id], :start_date => Date.new(2008, 1, 1))

    # in category, upcoming
    create_event(person, :name => 'upcoming event 1', :category_ids => [@category.id], :start_date => Date.new(2008, 1, 25))
    create_event(person, :name => 'upcoming event 2', :category_ids => [@category.id], :start_date => Date.new(2008, 1, 27))

    # not in category
    create_event(person, :name => 'event not in category')

    get :category_index, :category_path => ['my-category']

    assert_equal [ 'upcoming event 1', 'upcoming event 2' ], assigns(:results)[:events].map(&:name)
  end


  %w[ people enterprises articles events communities products ].each do |asset|
    should "render asset-specific template when searching for #{asset}" do
      get :index, :find_in => [ asset ]
      assert_template asset
    end
  end

  should 'list only categories with products' do
    cat1 = ProductCategory.create!(:name => 'pc test 1', :environment => Environment.default)
    cat2 = ProductCategory.create!(:name => 'pc test 2', :environment => Environment.default)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    
    cat1.products.create!(:name => 'prod test 1', :enterprise => ent)
    
    get :index, :find_in => 'products', :query => 'test'

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /pc test 1/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /pc test c/ }
  end

  should 'display only within a product category when specified' do
    prod_cat = ProductCategory.create!(:name => 'prod cat test', :environment => Environment.default)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')

    p = prod_cat.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'products', :product_category => prod_cat.id

    assert_includes assigns(:results)[:products], p
  end

  should 'display properly in conjuntion with a category' do
    cat = Category.create(:name => 'cat', :environment => Environment.default)
    prod_cat1 = ProductCategory.create!(:name => 'prod cat test 1', :environment => Environment.default)
    prod_cat2 = ProductCategory.create!(:name => 'prod cat test 2', :environment => Environment.default, :parent => prod_cat1)
    ent = create_profile_with_optional_category(Enterprise, 'test ent', cat)

    p = prod_cat2.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'products', :category_path => cat.path.split('/'), :product_category => prod_cat1.id

    assert_includes assigns(:results)[:products], p
  end

  should 'display only top level product categories that has products when no product category filter is specified' do
    cat1 = ProductCategory.create(:name => 'prod cat 1', :environment => Environment.default)
    cat2 = ProductCategory.create(:name => 'prod cat 2', :environment => Environment.default)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    p = cat1.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'products'

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 1/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 2/ }
  end

  should 'display children categories that has products when product category filter is selected' do
    cat1 = ProductCategory.create(:name => 'prod cat 1', :environment => Environment.default)
    cat11 = ProductCategory.create(:name => 'prod cat 11', :environment => Environment.default, :parent => cat1)
    cat12 = ProductCategory.create(:name => 'prod cat 12', :environment => Environment.default, :parent => cat1)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    p = cat11.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'products', :product_category => cat1.id

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 11/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 12/ }
  end

  should 'list only product categories with enterprises' do
    cat1 = ProductCategory.create!(:name => 'pc test 1', :environment => Environment.default)
    cat2 = ProductCategory.create!(:name => 'pc test 2', :environment => Environment.default)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')

    cat1.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'enterprises', :query => 'test'

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /pc test 1/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /pc test c/ }
  end

  should 'display only enterprises in the product category when its specified' do
    prod_cat = ProductCategory.create!(:name => 'prod cat test', :environment => Environment.default)
    ent1 = create_profile_with_optional_category(Enterprise, 'test_ent1')
    p = prod_cat.products.create!(:name => 'prod test 1', :enterprise => ent1)

    ent2 = create_profile_with_optional_category(Enterprise, 'test_ent2')

    get :index, :find_in => 'enterprises', :product_category => prod_cat.id

    assert_includes assigns(:results)[:enterprises], ent1
    assert_not_includes assigns(:results)[:enterprises], ent2
  end

  should 'display enterprises properly in conjuntion with a category' do
    cat = Category.create(:name => 'cat', :environment => Environment.default)
    prod_cat1 = ProductCategory.create!(:name => 'prod cat test 1', :environment => Environment.default)
    prod_cat2 = ProductCategory.create!(:name => 'prod cat test 2', :environment => Environment.default, :parent => prod_cat1)
    ent1 = create_profile_with_optional_category(Enterprise, 'test ent 1', cat)
    p = prod_cat2.products.create!(:name => 'prod test 1', :enterprise => ent1)

    ent2 = create_profile_with_optional_category(Enterprise, 'test ent 2', cat)

    get :index, :find_in => 'enterprises', :category_path => cat.path.split('/'), :product_category => prod_cat1.id

    assert_includes assigns(:results)[:enterprises], ent1
    assert_not_includes assigns(:results)[:enterprises], ent2
  end

  should 'display only top level product categories that has enterprises when no product category filter is specified' do
    cat1 = ProductCategory.create(:name => 'prod cat 1', :environment => Environment.default)
    cat2 = ProductCategory.create(:name => 'prod cat 2', :environment => Environment.default)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    p = cat1.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'enterprises'

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 1/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 2/ }
  end

  should 'display children categories that has enterprises when product category filter is selected' do
    cat1 = ProductCategory.create(:name => 'prod cat 1', :environment => Environment.default)
    cat11 = ProductCategory.create(:name => 'prod cat 11', :environment => Environment.default, :parent => cat1)
    cat12 = ProductCategory.create(:name => 'prod cat 12', :environment => Environment.default, :parent => cat1)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    p = cat11.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'enterprises', :product_category => cat1.id

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 11/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 12/ }
  end

  should 'load two level of the product categories tree' do
    cat1 = ProductCategory.create(:name => 'prod cat 1', :environment => Environment.default)
    cat11 = ProductCategory.create(:name => 'prod cat 11', :environment => Environment.default, :parent => cat1)
    cat12 = ProductCategory.create(:name => 'prod cat 12', :environment => Environment.default, :parent => cat1)
    ent = create_profile_with_optional_category(Enterprise, 'test ent')
    p = cat11.products.create!(:name => 'prod test 1', :enterprise => ent)

    get :index, :find_in => 'enterprises'

    assert_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 11/ }
    assert_no_tag :attributes => { :id => "product-categories-menu" }, :descendant => { :tag => 'a', :content => /prod cat 12/ }
  end

  should 'provide calendar for events' do
    get :index, :find_in => [ 'events' ]
    assert_equal 0, assigns(:calendar).size % 7
  end

  should 'display current year/month by default as caption of current month' do
    Date.expects(:today).returns(Date.new(2008, 8, 1)).at_least_once

    get :assets, :asset => 'events'
    assert_tag :tag => 'table', :attributes => {:class => /current-month/}, :descendant => {:tag => 'caption', :content => /August 2008/}
  end

  should 'submit search form to /search when viewing asset' do
    get :index, :asset => 'people'
    assert_tag :tag => "form", :attributes => { :class => 'search_form', :action => '/search' }
  end

  should 'treat blank input for the city id' do
    get :index, :city => ''

    assert_equal nil, assigns(:region)
  end
  
  should 'treat non-numeric input for the city id' do
    get :index, :city => 'bla'

    assert_equal nil, assigns(:region)
  end

  should 'found TextileArticle in articles' do
    person = create_user('teste').person
    art = TextileArticle.create!(:name => 'an text_article article to be found', :profile => person)

    get 'index', :query => 'article found', :find_in => [ 'articles' ]

    assert_includes assigns(:results)[:articles], art
  end

  should 'know about disabled assets' do
    env = mock
    %w[ articles enterprises people communities events].each do |item|
      env.expects(:enabled?).with('disable_asset_' + item).returns(false).at_least_once
    end
    env.expects(:enabled?).with('disable_asset_products').returns(true).at_least_once
    @controller.stubs(:environment).returns(env)

    %w[ articles enterprises people communities events].each do |item|
      assert_includes @controller.where_to_search.map(&:first), item.to_sym
    end
    assert_not_includes @controller.where_to_search.map(&:first), :products
  end

  should 'search for products by origin and radius correctly' do
    s = City.create!(:name => 'Salvador', :lat => -12.97, :lng => -38.51, :environment => Environment.default)
    e1 = create_profile_with_optional_category(Enterprise, 'test ent 1', nil, :lat => -12.97, :lng => -38.51)
    p1 = e1.products.create!(:name => 'test_product1', :product_category => @product_category)
    e2 = create_profile_with_optional_category(Enterprise, 'test ent 2', nil, :lat => -14.97, :lng => -40.51)
    p2 = e2.products.create!(:name => 'test_product2', :product_category => @product_category)

    get :assets, :asset => 'products', :city => s.id, :radius => 15

    assert_includes assigns(:results)[:products], p1
    assert_not_includes assigns(:results)[:products], p2
  end

  should 'show link to article asset in the see all foot link of the most_commented_articles block in the category page' do
    art = create_user('teste').person.articles.create!(:name => 'an article to be found')
    most_commented = [art]
    finder = CategoryFinder.new(@category)
    finder.expects(:most_commented_articles).returns(most_commented)
    CategoryFinder.expects(:new).with(@category).returns(finder)

    get :category_index, :category_path => [ 'my-category' ]
    assert_tag :tag => 'div', :attributes => {:class => /search-results-most_commented_articles/} , :descendant => {:tag => 'a', :attributes => { :href => '/search/index/my-category?asset=articles'}}
  end

  should 'display correct title on list communities' do
    get :assets, :asset => 'communities'
    assert_tag :tag => 'h1', :content => 'Communities'
  end

  should 'indicate more than page for total_entries' do
    Enterprise.destroy_all
    ('1'..'20').each do |n|
      create_profile_with_optional_category(Enterprise, 'test ' + n)
    end

    get :index, :query => 'test'

    assert_equal 20, assigns(:results)[:enterprises].total_entries
  end

  should 'add link to list in all categories when in a category' do
    ['people', 'enterprises', 'products', 'communities', 'articles'].each do |asset|
      get :index, :asset => asset, :category_path => [ 'my-category' ]
      assert_tag :tag => 'div', :content => 'In all categories'
    end
  end

  should 'not add link to list in all categories when not in a category' do
    ['people', 'enterprises', 'products', 'communities', 'articles'].each do |asset|
      get :index, :asset => asset
      assert_no_tag :tag => 'div', :content => 'In all categories'
    end
  end

  should 'find products when enterprises has own hostname' do
    ent = create_profile_with_optional_category(Enterprise, 'teste')
    ent.domains << Domain.new(:name => 'testent.com'); ent.save!
    prod = ent.products.create!(:name => 'a beautiful product', :product_category => @product_category)
    get 'index', :query => 'beautiful', :find_in => ['products']
    assert_includes assigns(:results)[:products], prod
  end

  should 'add script tag for google maps if searching products' do
    get 'index', :query => 'product', :display => 'map', :find_in => ['products']

    assert_tag :tag => 'script', :attributes => { :src => 'http://maps.google.com/maps?file=api&amp;v=2&amp;key=ENVIRONMENT_KEY'}
  end

  should 'add script tag for google maps if searching enterprises' do
    get 'index', :query => 'enterprise', :display => 'map', :find_in => ['enterprises']

    assert_tag :tag => 'script', :attributes => { :src => 'http://maps.google.com/maps?file=api&amp;v=2&amp;key=ENVIRONMENT_KEY'}
  end

  should 'not add script tag for google maps if searching articles' do
    get 'index', :query => 'article', :display => 'map', :find_in => ['articles']

    assert_no_tag :tag => 'script', :attributes => { :src => 'http://maps.google.com/maps?file=api&amp;v=2&amp;key=ENVIRONMENT_KEY'}
  end

  should 'not add script tag for google maps if searching people' do
    get 'index', :query => 'person', :display => 'map', :find_in => ['people']

    assert_no_tag :tag => 'script', :attributes => { :src => 'http://maps.google.com/maps?file=api&amp;v=2&amp;key=ENVIRONMENT_KEY'}
  end

  should 'not add script tag for google maps if searching communities' do
    get 'index', :query => 'community', :display => 'map', :find_in => ['communities']

    assert_no_tag :tag => 'script', :attributes => { :src => 'http://maps.google.com/maps?file=api&amp;v=2&amp;key=ENVIRONMENT_KEY'}
  end

  should 'show events of specific day' do
    person = create_user('anotheruser').person
    event = create_event(person, :name => 'Joao Birthday', :start_date => Date.new(2009, 10, 28))

    get :events_by_day, :year => 2009, :month => 10, :day => 28

    assert_tag :tag => 'a', :content => /Joao Birthday/
  end

  should 'filter events by category' do
    person = create_user('anotheruser').person

    searched_category = Category.create!(:name => 'Category with events', :environment => Environment.default)

    event_in_searched_category = create_event(person, :name => 'Maria Birthday', :start_date => Date.today, :category_ids => [searched_category.id])
    event_in_non_searched_category = create_event(person, :name => 'Joao Birthday', :start_date => Date.today, :category_ids => [@category.id])

    get :assets, :asset => 'events', :category_path => ['category-with-events']

    assert_includes assigns(:events_of_the_day), event_in_searched_category
    assert_not_includes assigns(:events_of_the_day), event_in_non_searched_category
  end

  should 'filter events by category of specific day' do
    person = create_user('anotheruser').person

    searched_category = Category.create!(:name => 'Category with events', :environment => Environment.default)

    event_in_searched_category = create_event(person, :name => 'Maria Birthday', :start_date => Date.new(2009, 10, 28), :category_ids => [searched_category.id])
    event_in_non_searched_category = create_event(person, :name => 'Joao Birthday', :start_date => Date.new(2009, 10, 28), :category_ids => [@category.id])

    get :events_by_day, :year => 2009, :month => 10, :day => 28, :category_id => searched_category.id

    assert_tag :tag => 'a', :content => /Maria Birthday/
    assert_no_tag :tag => 'a', :content => /Joao Birthday/
  end

  should 'ignore filter of events if category not exists' do
    person = create_user('anotheruser').person
    create_event(person, :name => 'Joao Birthday', :start_date => Date.new(2009, 10, 28), :category_ids => [@category.id])
    create_event(person, :name => 'Maria Birthday', :start_date => Date.new(2009, 10, 28))

    id_of_unexistent_category = Category.last.id + 10

    get :events_by_day, :year => 2009, :month => 10, :day => 28, :category_id => id_of_unexistent_category

    assert_tag :tag => 'a', :content => /Joao Birthday/
    assert_tag :tag => 'a', :content => /Maria Birthday/
  end

  ##################################################################
  ##################################################################

  def create_event(profile, options)
    ev = Event.new({ :name => 'some event', :start_date => Date.new(2008,1,1) }.merge(options))
    ev.profile = profile
    ev.save!
    ev
  end

end
