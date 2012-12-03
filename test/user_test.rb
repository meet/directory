require 'test_helper'

require 'directory/test_help'

class UserTest < Test::Unit::TestCase
  
  def setup
    Directory.connect_with :base => 'dc=example,dc=com'
    Directory.backend = Directory::MockLDAP
  end
  
  def teardown
    Directory.connection.clear_mocks
    Directory.connection.clear_changes
  end
  
  def test_privileged
    Directory.connection.mock_user(:uid => 'user1')
    Directory.connection.mock_user(:uid => 'user2')
    Directory.connection.mock_user(:uid => 'user3')
    
    Directory.connection.mock_group(:cn => 'group', :memberuid => [ 'user1', 'user2', 'user3' ])
    Directory.connection.mock_group(:cn => 'managers', :memberuid => 'user2')
    Directory.connection.mock_group(:cn => 'admins', :memberuid => 'user1')
    
    user1, user2, user3 = Directory::User.all
    
    assert user1.admin?(user2)
    assert user1.admin?(user3)
    assert user1.manager?
    
    assert ! user2.admin?(user1)
    assert user2.admin?(user3)
    assert user2.manager?
    
    assert ! user2.admin?(user1)
    assert ! user3.admin?(user2)
    assert ! user3.manager?
  end
  
  def test_mail
    Directory.connection.mock_user(:uid => 'user')
    assert_equal 'user@example.com', Directory::User.find('user').mail
  end
  
  def test_set_enabled
    Directory.connection.mock_user(:uid => 'user')
    dn = 'uid=user,ou=users,dc=example,dc=com'
    
    user = Directory::User.new(Hash.new([]).merge({ :dn => [ dn ] }))
    user.enabled = false
    
    assert_equal [ Directory::MockLDAP::Change.new(dn, :shadowexpire, [ '0' ]) ],
                 Directory.connection.changes
  end
  
  def test_set_mail_forward
    Directory.connection.mock_user(:uid => 'user')
    dn = 'uid=user,ou=users,dc=example,dc=com'
    
    user = Directory::User.new(Hash.new([]).merge({ :dn => [ dn ] }))
    user.mail_forward = 'example@example.com'
    
    assert_equal [ Directory::MockLDAP::Change.new(dn, :mail, [ 'example@example.com' ]) ],
                 Directory.connection.changes
  end
  
  def test_set_password
    Directory.connection.mock_user(:uid => 'user')
    dn = 'uid=user,ou=users,dc=example,dc=com'
    
    user = Directory::User.new(Hash.new([]).merge({ :dn => [ dn ] }))
    user.password = 'super_secret'
    
    assert_equal 1, Directory.connection.changes.size
    assert_equal dn, Directory.connection.changes.first.dn
    assert_equal :userpassword, Directory.connection.changes.first.attribute
    hash = Base64.decode64(Directory.connection.changes.first.value.first.sub('{SSHA}', ''))
    salt = hash[-4..-1]
    assert_equal Digest::SHA1.digest('super_secret'+salt)+salt, hash
  end
  
  def test_passworded
    Directory.connection.mock_user(:uid => 'user1')
    assert ! Directory::User.find('user1').passworded
    
    Directory.connection.mock_user(:uid => 'user2', :userpassword => 'secret')
    assert Directory::User.find('user2').passworded
    
    assert_equal [], Directory.connection.changes
  end
  
end
