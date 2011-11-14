class ProfileDesignController < BoxOrganizerController

  needs_profile

  protect 'edit_profile_design', :profile
  
  def available_blocks
    blocks = [ ArticleBlock, TagsBlock, RecentDocumentsBlock, ProfileInfoBlock, LinkListBlock, MyNetworkBlock, FeedReaderBlock, ProfileImageBlock, LocationBlock, SlideshowBlock, ProfileSearchBlock ]

    # blocks exclusive for organizations
    if profile.has_members?
      blocks << MembersBlock
    end

    # blocks exclusive to person
    if profile.person?
      blocks << FriendsBlock
      blocks << FavoriteEnterprisesBlock
      blocks << CommunitiesBlock
      blocks << EnterprisesBlock
    end

    # blocks exclusive for enterprises
    if profile.enterprise?
      blocks << DisabledEnterpriseMessageBlock
      blocks << HighlightsBlock
      blocks << FeaturedProductsBlock
      blocks << FansBlock
    end

    # product block exclusive for enterprises in environments that permits it
    if profile.enterprise? && !profile.environment.enabled?('disable_products_for_enterprises')
      blocks << ProductsBlock
    end

    # block exclusive to profile has blog
    if profile.has_blog?
      blocks << BlogArchivesBlock
    end

    if user.is_admin?(profile.environment)
      blocks << RawHTMLBlock
    end

    blocks
  end

end
