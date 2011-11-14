class ProductsBlock < Block

  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionController::UrlWriter

  def self.description
    _('Products')
  end

  def default_title
    _('Products')
  end

  def help
    _('This block presents a list of your products.')
  end

  def content
    block_title(title) +
    content_tag(
      'ul',
      products.map {|product|
        content_tag('li',
          link_to( product.name,
                   product.url,
                   :style => 'background-image:url(%s)' % product.default_image('minor')
                 ),
          :class => 'product'
        )
      }
    )
  end

  def footer
    link_to(_('View all products'), owner.public_profile_url.merge(:controller => 'catalog', :action => 'index'))
  end

  settings_items :product_ids, Array
  def product_ids=(array)
    self.settings[:product_ids] = array
    if self.settings[:product_ids]
      self.settings[:product_ids] = self.settings[:product_ids].map(&:to_i)
    end
  end

  def products(reload = false)
    if product_ids.blank?
      products_list = owner.products(reload)
      result = []
      [4, products_list.size].min.times do
        p = products_list.rand
        result << p
        products_list -= [p]
      end
      result
    else
      product_ids.map {|item| owner.products.find(item) }
    end
  end

end
