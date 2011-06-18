require_dependency 'ext/enterprise'

class BscPlugin < Noosfero::Plugin

  Bsc

  def self.plugin_name
    "BSC"
  end

  def self.plugin_description
    _("Adds the Bsc feature")
  end

end
