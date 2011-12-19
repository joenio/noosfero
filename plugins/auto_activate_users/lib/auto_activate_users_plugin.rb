require_dependency 'user'

class User
  after_create do |user|
    user.activate
  end
end
class AutoActivateUsersPlugin < Noosfero::Plugin
  def self.plugin_name
    "AutoActivateUsersPlugin"
  end
  def self.plugin_description
    _("A plugin that activate new users automatically.")
  end
end
