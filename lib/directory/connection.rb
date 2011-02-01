# Represents the LDAP directory.
module Directory
  
  @@backend = Net::LDAP
  @@connection = nil
  @@connection_params = { }
  
  # Set the backend, which defaults to Net::LDAP. See MockLDAP.
  def self.backend=(backend)
    @@backend = backend
  end
  
  # Add connection parameters. Discards any current connection.
  def self.connect_with(connection_params)
    @@connection = nil
    @@connection_params.merge!(connection_params)
  end
  
  # Obtain the current LDAP connection, creating one if necessary.
  def self.connection
    @@connection ||= new
  end
  
  # Obtain a new LDAP connection that is not cached. Useful with bind.
  def self.new
    @@backend.new(@@connection_params).extend Search
  end
  
  module Search
    
    def find_by_dn(dn, &block)
      search(:base => dn, :scope => Net::LDAP::SearchScope_BaseObject, &block)
    end
    
    def all_users(&block)
      search(:base => "ou=users,#{base}", :filter => Net::LDAP::Filter.pres('uid'), &block)
    end
    
    def find_user_by_uid(uid, &block)
      search(:base => "ou=users,#{base}", :filter => Net::LDAP::Filter.eq('uid', "#{uid}"), &block)
    end
    
    def find_users_by_match(query, &block)
      search(:base => "ou=users,#{base}",
             :filter => Net::LDAP::Filter.eq('uid', "*#{query}*") | Net::LDAP::Filter.eq('cn', "*#{query}*"),
             &block)
    end
    
    def all_groups(&block)
      search(:base => "ou=groups,#{base}", :filter => Net::LDAP::Filter.pres('cn'), &block)
    end
    
    def find_group_by_cn(cn, &block)
      search(:base => "ou=groups,#{base}", :filter => Net::LDAP::Filter.eq('cn', "#{cn}"), &block)
    end
    
    def find_groups_by_member_uid(uid, &block)
      search(:base => "ou=groups,#{base}", :filter => Net::LDAP::Filter.eq('memberuid', "#{uid}"), &block)
    end
    
    def find_groups_by_match(query, &block)
      search(:base => "ou=groups,#{base}",
             :filter => Net::LDAP::Filter.eq('cn', "*#{query}*") | Net::LDAP::Filter.eq('description', "*#{query}*"),
             &block)
    end
    
    def find_app_by_url(url, &block)
      search(:base => "ou=apps,#{base}", :filter => Net::LDAP::Filter.eq('labeleduri', "#{url}"), &block)
    end
    
  end
  
end
