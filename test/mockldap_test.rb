require 'test_helper'

require 'directory/test_help'

class MockLDAPTest < Test::Unit::TestCase
  
  def setup
    Directory.connect_with :base => 'dc=example'
    Directory.backend = Directory::MockLDAP
  end
  
  def teardown
    Directory.connection.clear_mocks
  end
  
  def test_mock_user
    Directory.connection.mock_user(:uid => 'lmb', :givenname => 'Loren', :sn => 'Berry')
    lmb = { :uid => ['lmb'], :givenname => ['Loren'], :sn => ['Berry'], :dn => ['uid=lmb,ou=users,dc=example'] }
    
    Directory.connection.mock_user(:uid => 'rhd', :givenname => 'Reuben', :sn => 'Donnelley')
    rhd = { :uid => ['rhd'], :givenname => ['Reuben'], :sn => ['Donnelley'], :dn => ['uid=rhd,ou=users,dc=example'] }
    
    assert_equal [ lmb ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                      :filter => Net::LDAP::Filter.eq('uid', 'lmb'))
    assert_equal [ rhd ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                      :filter => Net::LDAP::Filter.eq('uid', 'rhd'))
    assert_equal [ lmb ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                      :filter => Net::LDAP::Filter.eq('sn', 'Berry'))
    assert_equal [ rhd ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                      :filter => Net::LDAP::Filter.eq('sn', 'Donnelley'))
    assert_equal [ ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                  :filter => Net::LDAP::Filter.eq('uid', 'Loren'))
    assert_equal [ ], Directory.connection.search(:base => 'ou=groups,dc=example',
                                                  :filter => Net::LDAP::Filter.eq('uid', 'lmb'))
    assert_equal [ lmb, rhd ], Directory.connection.search(:base => 'ou=users,dc=example',
                                                           :filter => Net::LDAP::Filter.pres('givenname'))
  end
  
end
