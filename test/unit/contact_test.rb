require File.dirname(__FILE__) + '/../test_helper'

class ContactTest < ActiveSupport::TestCase

  should 'validates required fields' do
    contact = Contact.new
    assert !contact.valid?

    contact.subject = 'Hi'
    assert !contact.valid?

    contact.name = 'john'
    assert !contact.valid?

    contact.email = 'visitor@invalid.com'
    assert !contact.valid?

    contact.message = 'Hi, all'
    assert contact.valid?
  end

  should 'validates format of email only if not empty' do
    contact = Contact.new
    contact.valid?
    assert_match(/^.* can't be blank$/, contact.errors[:email])
  end

  should 'inicialize fields on instanciate' do
    assert_nothing_raised ArgumentError do
      Contact.new(:name => 'john', :email => 'contact@invalid.com')
    end
  end

  should 'deliver message' do
    ent = fast_create(Enterprise, :name => 'my enterprise', :identifier => 'myent')
    c = Contact.new(:name => 'john', :email => 'john@invalid.com', :subject => 'hi', :message => 'hi, all', :dest => ent)
    assert c.deliver
  end

  should 'not deliver message if contact is invalid' do
    ent = fast_create(Enterprise, :name => 'my enterprise', :identifier => 'myent')
    c = Contact.new(:name => 'john', :subject => 'hi', :message => 'hi, all', :dest => ent)
    assert !c.valid?
    assert !c.deliver
  end

  should 'use sender name and environment contact_email on from' do
    ent = fast_create(Enterprise, :name => 'my enterprise', :identifier => 'myent')
    c = Contact.new(:name => 'john', :email => 'john@invalid.com', :subject => 'hi', :message => 'hi, all', :dest => ent)
    email = c.deliver
    assert_equal "#{c.name} <#{ent.environment.contact_email}>", email['from'].to_s
  end

  should 'add dest name on subject' do
    ent = fast_create(Enterprise, :name => 'my enterprise', :identifier => 'myent')
    c = Contact.new(:name => 'john', :email => 'john@invalid.com', :subject => 'hi', :message => 'hi, all', :dest => ent)
    email = c.deliver
    assert_equal "[#{ent.short_name(30)}] #{c.subject}", email['subject'].to_s
  end

  should 'add sender email on reply_to' do
    ent = fast_create(Enterprise, :name => 'my enterprise', :identifier => 'myent')
    c = Contact.new(:name => 'john', :email => 'john@invalid.com', :subject => 'hi', :message => 'hi, all', :dest => ent)
    email = c.deliver
    assert_equal c.email, email.reply_to.to_s
  end

end
