class BscPlugin::Bsc < Enterprise

  has_many :enterprises
  has_many :enterprise_requests, :class_name => 'BscPlugin::AssociateEnterprise'
  has_many :products, :finder_sql => 'select * from products where enterprise_id in (#{enterprises.map(&:id).join(",")})'
  has_many :contracts, :class_name => 'BscPlugin::Contract'

  validates_presence_of :nickname
  validates_presence_of :company_name
  validates_presence_of :cnpj
  validates_uniqueness_of :nickname
  validates_uniqueness_of :company_name
  validates_uniqueness_of :cnpj

  named_scope :with_article_or_contract_in_period, lambda { |from, to|
    article_conditions = []
    article_conditions << (from ? "(articles.created_at >= '#{from}'" : nil)
    article_conditions << (to ? "articles.created_at < '#{to+1.day}')" : nil)
    article_conditions = article_conditions.compact.join(' AND ')

    contract_conditions = []
    contract_conditions << (from ? "(bsc_plugin_contracts.created_at >= '#{from}'" : nil)
    contract_conditions << (to ? "bsc_plugin_contracts.created_at < '#{to+1.day}')" : nil)
    contract_conditions = contract_conditions.compact.join(' AND ')

    conditions = [article_conditions, contract_conditions].compact.join(' OR ')

    { :joins => "INNER JOIN articles ON profiles.id = articles.profile_id 
                 INNER JOIN bsc_plugin_contracts ON profiles.id = bsc_plugin_contracts.bsc_id",
      :select => 'DISTINCT profiles.*',
      :conditions => [conditions]
    }
  }

  before_validation do |bsc|
    bsc.name = bsc.business_name || 'Sample name'
  end

  def already_requested?(enterprise)
    enterprise_requests.pending.map(&:enterprise).include?(enterprise)
  end

  def enterprises_to_token_input
    enterprises.map { |enterprise| {:id => enterprise.id, :name => enterprise.name} }
  end

  def control_panel_settings_button
    {:title => _('Bsc info and settings'), :icon => 'edit-profile-enterprise'}
  end

  def create_product?
    false
  end

  def self.identification
    'Bsc'
  end

end
