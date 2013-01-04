require 'test_helper'

require 'directory/test_help'

class NewUserTest < Test::Unit::TestCase
  
  def setup
    Directory.connect_with :base => 'dc=example,dc=com'
    Directory.backend = Directory::MockLDAP
    
    Directory.connection.mock_user(:uid => 'creator')
    Directory.connection.mock_group(:cn => 'group')
  end
  
  def teardown
    Directory.connection.clear_mocks
    Directory.connection.clear_changes
  end
  
  def test_valid
    invitee = user_to_save
    assert invitee.valid_to_save?
    assert ! invitee.valid_to_create?
    
    invited = user_to_create('abc123', { :username => 'test', :mail_inbox => true })
    assert invited.valid_to_save?
    assert invited.valid_to_create?
  end
  
  def test_forewarned
    naive = user_to_save(:first_name => 'new')
    assert ! naive.forewarned?
    assert ! naive.valid_to_save?
    
    warned = user_to_save(:first_name => 'new', :warned => 'first_name')
    assert warned.forewarned?
    assert warned.valid_to_save?
  end
  
  def test_save
    user_to_save.save
    
    cn = find_change(nil, :cn)
    dn = "cn=#{cn},ou=newusers,dc=example,dc=com"
    assert_equal [ 'example@outside.com' ], find_change(dn, :mail)
    assert_equal [ 'group' ], find_change(dn, :ou)
    assert_equal [ 'uid=creator,ou=users,dc=example,dc=com' ], find_change(dn, :manager)
  end
  
  def test_create
    user_to_create('abc123', { :username => 'test' }).create
    
    assert_equal nil, find_change('cn=abc123,ou=newusers,dc=example,dc=com', :dn)
    
    dn = 'uid=test,ou=users,dc=example,dc=com'
    assert_equal [ 'test' ], find_change(dn, :uid)
    assert_equal [ 'example@outside.com' ], find_change(dn, :mail)
    assert find_change(dn, :uidnumber).first.to_i > 0
    assert find_change(dn, :gidnumber).first.to_i > 0
    
    assert_equal [ 'test' ], find_change('cn=group,ou=groups,dc=example,dc=com', :memberuid)
  end
  
  private
    
    def user_to_save(attributes = {})
      opts = { :first_name => 'New', :last_name => 'User',
               :mail_forward => 'example@outside.com',
               :primary_group => 'group',
               :requester => Directory::User.find('creator') }.merge(attributes)
      return Directory::NewUser.new(opts)
    end
    
    def user_to_create(cn, attributes = {})
      Directory.connection.mock_new_user(:cn => cn,
                                         :givenname => 'New', :sn => 'User',
                                         :mail => 'example@outside.com',
                                         :ou => 'group',
                                         :manager => 'uid=creator,ou=users,dc=example,dc=com')
      return Directory::NewUser.find_and_update(cn, attributes)
    end
    
    def find_change(dn, attribute)
      return Directory.connection.changes.find do |change|
        (dn ? change.dn == dn : true) && change.attribute == attribute
      end .value
    end
    
end
