require File.dirname(__FILE__) + '/../../../../../test/test_helper'
require File.dirname(__FILE__) + '/../../../../../app/models/uploaded_file'
require File.dirname(__FILE__) + '/../../../../../app/models/product'
require File.dirname(__FILE__) + '/../../../lib/ext/product'

class ProductTest < Test::Unit::TestCase
  VALID_CNPJ = '94.132.024/0001-48'

  should 'return the bsc as enterprise if enterprise is not validated and has a bsc' do
    bsc = BscPlugin::Bsc.create!({:business_name => 'Sample Bsc', :identifier => 'sample-bsc', :company_name => 'Sample Bsc Ltda.', :cnpj => VALID_CNPJ})
    e1 = fast_create(Enterprise, :validated => true)
    e2 = fast_create(Enterprise, :validated => false, :bsc_id => bsc.id)

    p1 = fast_create(Product, :enterprise_id => e1.id)
    p2 = fast_create(Product, :enterprise_id => e2.id)

    assert_equal e1, p1.enterprise
    assert_equal bsc, p2.enterprise
  end
end
