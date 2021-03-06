include ShoppingCartPlugin::CartHelper

class ShoppingCartPluginProfileController < ProfileController
  append_view_path File.join(File.dirname(__FILE__) + '/../views')
  before_filter :login_required, :only => []

  before_filter :login_required, :only => []

  def add
    session[:cart] = { :enterprise_id => profile.id, :items => {} } if session[:cart].nil?
    if validate_same_enterprise && product = validate_enterprise_has_product(params[:id])
      session[:cart][:items][product.id] = 0 if session[:cart][:items][product.id].nil?
      session[:cart][:items][product.id] += 1
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :products => [{
          :id => product.id,
          :name => product.name,
          :price => get_price(product, profile.environment),
          :description => product.description,
          :picture => product.default_image(:minor),
          :quantity => session[:cart][:items][product.id]
        }]
      }.to_json
    end
  end

  def remove
    id = params[:id].to_i
    if validate_cart_presence && validate_cart_has_product(id)
      session[:cart][:items].delete(id)
      session[:cart] = nil if session[:cart][:items].empty?
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :product_id => id
      }.to_json
    end
  end

  def list
    if validate_cart_presence
      products = session[:cart][:items].collect do |id, quantity|
        product = Product.find(id)
        { :id => product.id,
          :name => product.name,
          :price => get_price(product, profile.environment),
          :description => product.description,
          :picture => product.default_image(:minor),
          :quantity => quantity
        }
      end
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :enterprise => Enterprise.find(session[:cart][:enterprise_id]).identifier,
        :products => products
      }.to_json
    end
  end

  def update_quantity
    quantity = params[:quantity].to_i
    id = params[:id].to_i
    if validate_cart_presence && validate_cart_has_product(id) && validate_item_quantity(quantity)
      product = Product.find(id)
      session[:cart][:items][product.id] = quantity
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :product_id => id,
        :quantity => quantity
      }.to_json
    end
  end

  def clean
    session[:cart] = nil
    render :text => {
      :ok => true,
      :error => {:code => 0}
    }.to_json
  end

  def buy
    @environment = profile.environment
    render :layout => false
  end

  def send_request
      register_order(params[:customer], session[:cart][:items])
    begin
      ShoppingCartPlugin::Mailer.deliver_customer_notification(params[:customer], profile, session[:cart][:items])
      ShoppingCartPlugin::Mailer.deliver_supplier_notification(params[:customer], profile, session[:cart][:items])
      render :text => {
        :ok => true,
        :message => _('Request sent successfully. Check your email.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 6,
          :message => exception.message
        }
      }.to_json
    end
  end

  def visibility
    render :text => session[:cart].has_key?(:visibility) ? session[:cart][:visibility].to_json : true.to_json
  end

  def show
    begin
      session[:cart][:visibility] = true
      render :text => {
        :ok => true,
        :message => _('Basket displayed.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 7,
          :message => exception.message
        }
      }.to_json
    end
  end

  def hide
    begin
      session[:cart][:visibility] = false
      render :text => {
        :ok => true,
        :message => _('Basket hidden.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 8,
          :message => exception.message
        }
      }.to_json
    end
  end

  private

  def validate_same_enterprise
    if profile.id != session[:cart][:enterprise_id]
      render :text => {
        :ok => false,
        :error => {
        :code => 1,
        :message => _("Can't join items from different enterprises.")
      }
      }.to_json
      return false
    end
    true
  end

  def validate_cart_presence
    if session[:cart].nil?
      render :text => {
        :ok => false,
        :error => {
        :code => 2,
        :message => _("There is no basket.")
      }
      }.to_json
      return false
    end
    true
  end

  def validate_enterprise_has_product(id)
    begin
      product = profile.products.find(id)
    rescue
      render :text => {
        :ok => false,
        :error => {
        :code => 3,
        :message => _("This enterprise doesn't have this product.")
      }
      }.to_json
      return nil
    end
    product
  end

  def validate_cart_has_product(id)
    if !session[:cart][:items].has_key?(id)
      render :text => {
        :ok => false,
        :error => {
        :code => 4,
        :message => _("The basket doesn't have this product.")
      }
      }.to_json
      return false
    end
    true
  end

  def validate_item_quantity(quantity)
    if quantity.to_i < 1
      render :text => {
        :ok => false,
        :error => {
        :code => 5,
        :message => _("Invalid quantity.")
      }
      }.to_json
      return false
    end
    true
  end

  def register_order(custumer, items)
    new_items = {}
    items.each do |id, quantity|
      new_items[id] = {:quantity => quantity, :price => Product.find(id).price}
    end
    ShoppingCartPlugin::PurchaseOrder.create!(
      :seller => profile,
      :customer => user,
      :status => ShoppingCartPlugin::PurchaseOrder::Status::OPENED,
      :products_list => new_items,
      :customer_name => params[:customer][:name],
      :customer_email => params[:customer][:email],
      :customer_contact_phone => params[:customer][:contact_phone],
      :customer_address => params[:customer][:address],
      :customer_city => params[:customer][:city],
      :customer_zip_code => params[:customer][:zip_code]
    )
  end
end
