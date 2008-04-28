class EnvironmentDesignController < BoxOrganizerController
  
  protect 'edit_environment_design', :environment

  def available_blocks
    @available_blocks ||= [ LoginBlock, EnvironmentStatisticsBlock, RecentDocumentsBlock, EnterprisesBlock, CommunitiesBlock, PeopleBlock ]
  end

end
