require File.dirname(__FILE__) + '/../test_helper'

class OrganizationMailingTest < ActiveSupport::TestCase

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @community = fast_create(Community)
    @person = create_user('john').person
    member_1 = create_user('user_one').person
    member_2 = create_user('user_two').person
    @community.add_member(member_1)
    @community.add_member(member_2)
  end
  attr_reader :community, :person

  should 'require source_id' do
    mailing = OrganizationMailing.new
    mailing.valid?
    assert mailing.errors.invalid?(:source_id)

    mailing.source_id = community.id
    mailing.valid?
    assert !mailing.errors.invalid?(:source_id)
  end

  should 'return community name' do
    mailing = OrganizationMailing.new(:source => community)
    assert_equal community.name, mailing.source.name
  end

  should 'return community with source_id' do
    mailing = OrganizationMailing.new(:source => community)
    assert_equal community, mailing.source
  end

  should 'return person with person_id' do
    mailing = OrganizationMailing.new(:source => community, :person => person)
    assert_equal person, mailing.person
  end

  should 'display name and email on generate_from' do
    mailing = OrganizationMailing.new(:source => community, :person => person)
    assert_equal "#{person.name} <#{community.environment.contact_email}>", mailing.generate_from
  end

  should 'generate subject' do
    mailing = OrganizationMailing.new(:source => community, :subject => 'Hello :)')
    assert_equal "[#{community.name}] #{mailing.subject}", mailing.generate_subject
  end

  should 'return signature message' do
    mailing = OrganizationMailing.new(:source => community)
    assert_equal "Sent by community #{community.name}.", mailing.signature_message
  end

  should 'return url for organization on url' do
    mailing = OrganizationMailing.new(:source => community)
    assert_equal "#{community.environment.top_url}/#{community.name.to_slug}", mailing.url
  end

  should 'deliver mailing to each member after create' do
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    process_delayed_job_queue
    assert_equal 2, ActionMailer::Base.deliveries.count
  end

  should 'create mailing sent to each recipient after delivering mailing' do
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    assert_difference MailingSent, :count, 2 do
      process_delayed_job_queue
    end
  end

  should 'change locale according to the mailing locale' do
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :locale => 'pt', :person => person)
    Noosfero.expects(:with_locale).with('pt')
    process_delayed_job_queue
  end

  should 'have community by source_id' do
    mailing = community.mailings.build(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    mailing.save!

    assert_equal community, Mailing.find(mailing.id).source
  end

  should 'return recipient' do
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    assert_equal [Person['user_one'], Person['user_two']], mailing.recipients
  end

  should 'return recipients according to limit' do
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    assert_equal [Person['user_one']], mailing.recipients(0, 1)
  end

  should 'return true if already sent mailing to a recipient' do
    member = Person['user_one']
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    process_delayed_job_queue
    assert mailing.mailing_sents.find_by_person_id(member.id)
  end

  should 'return false if did not sent mailing to a recipient' do
    recipient = fast_create(Person)
    mailing = OrganizationMailing.create(:source => community, :subject => 'Hello', :body => 'We have some news', :person => person)
    process_delayed_job_queue

    assert !mailing.mailing_sents.find_by_person_id(recipient.id)
  end

  protected
  include NoosferoTestHelper

end
