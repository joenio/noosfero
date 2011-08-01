require_dependency 'product'

class Product
  def enterprise_with_bsc
    return if enterprise_without_bsc.nil?
    if !enterprise_without_bsc.validated && enterprise_without_bsc.bsc
      enterprise_without_bsc.bsc
    else
      enterprise_without_bsc
    end
  end
  alias_method_chain :enterprise, :bsc
end
