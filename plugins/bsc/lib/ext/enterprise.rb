require_dependency 'enterprise'

class Enterprise
  belongs_to :bsc, :class_name => 'BscPlugin::Bsc'
end
