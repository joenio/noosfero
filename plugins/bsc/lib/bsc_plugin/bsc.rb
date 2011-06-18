class BscPlugin::Bsc < Enterprise

  has_many :enterprises

  validates_presence_of :nickname
  validates_presence_of :company_name
  validates_presence_of :cnpj
  validates_uniqueness_of :nickname
  validates_uniqueness_of :company_name
  validates_uniqueness_of :cnpj

  before_validation do |bsc|
    bsc.name = bsc.business_name || 'Sample name'
  end

  before_create do |bsc|
    bsc.validated = false
    bsc.enabled = true
  end

end
