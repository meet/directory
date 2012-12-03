require 'test_helper'

require 'directory/test_help'

class GroupTest < Test::Unit::TestCase
  
  def setup
    Directory.connect_with :base => 'dc=example,dc=com'
    Directory.backend = Directory::MockLDAP
  end
  
  def teardown
    Directory.connection.clear_mocks
    Directory.connection.clear_changes
  end
  
  def test_find
    Directory.connection.mock_group(:cn => 'group')
    dn = 'cn=group,ou=groups,dc=example,dc=com'
    
    assert_equal dn, Directory::Group.find('group').dn
    assert_equal dn, Directory::Group.find_by_mail('group@example.com').dn
    assert ! Directory::Group.find_by_mail('group@elsewhere.com')
  end
  
end
