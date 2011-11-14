require_dependency 'user'

class User
  after_create do |user|
    user.activate
  end
end
class AutoActivateUserPlugin < Noosfero::Plugin
  def self.plugin_name
    "AutoActivateUserPlugin"
  end
  def self.plugin_description
    _("A plugin that activate users automatically.")
  end
end
