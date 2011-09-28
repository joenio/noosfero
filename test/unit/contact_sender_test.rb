require File.dirname(__FILE__) + '/../test_helper'

class ContactSenderTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

  end

  should 'be able to deliver mail' do
    ent = Enterprise.new(:name => 'my enterprise', :identifier => 'myent', :environment => Environment.default)
    ent.contact_email = 'contact@invalid.com'
    c = build(Contact, :dest => ent)
    response = Contact::Sender.deliver_mail(c)
    assert_equal Environment.default.contact_email, response.from.to_s
    assert_equal "[#{ent.name}] #{c.subject}", response.subject
  end

  should 'deliver mail to contact_email' do
    ent = Enterprise.new(:name => 'my enterprise', :identifier => 'myent', :environment => Environment.default)
    ent.contact_email = 'contact@invalid.com'
    c = build(Contact, :dest => ent)
    response = Contact::Sender.deliver_mail(c)
    assert_includes response.to, c.dest.contact_email
  end
 
  should 'deliver mail to admins of enterprise' do
    admin = create_user('admin_test').person
    ent = Enterprise.create!(:name => 'my enterprise', :identifier => 'myent', :environment => Environment.default)
    ent.contact_email = 'contact@invalid.com'
    ent.add_admin(admin)
    assert ent.save!
    c = build(Contact, :dest => ent)
    response = Contact::Sender.deliver_mail(c)
    assert_includes response.to, admin.email
  end

  should 'deliver a copy of email if requester wants' do
    ent = Enterprise.new(:name => 'my enterprise', :identifier => 'myent', :environment => Environment.default)
    c = build(Contact, :dest => ent, :email => 'requester@invalid.com', :receive_a_copy => true)
    response = Contact::Sender.deliver_mail(c)
    assert_includes response.cc, c.email
  end

  should 'not deliver a copy of email if requester dont wants' do
    ent = Enterprise.new(:name => 'my enterprise', :identifier => 'myent', :environment => Environment.default)
    c = build(Contact, :dest => ent, :email => 'requester@invalid.com', :receive_a_copy => false)
    response = Contact::Sender.deliver_mail(c)
    assert_nil response.cc
  end

  should 'only deliver mail to email of person' do
    person = create_user('contacted_user').person
    c = build(Contact, :dest => person)
    response = Contact::Sender.deliver_mail(c)
    assert_equal [person.email], response.to
  end

  should 'identify the sender in the message headers' do
    recipient = create_user('contacted_user').person
    sender = create_user('sender_user').person
    c = build(Contact, :dest => recipient, :sender => sender)
    sent_message = Contact::Sender.deliver_mail(c)
    assert_equal 'sender_user', sent_message['X-Noosfero-Sender'].to_s
  end

  private

    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/mail_sender/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end

end
