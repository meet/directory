# Represents the LDAP directory.
module Directory
  
  @@backend = Net::LDAP
  @@connection = nil
  @@connection_params = { }
  
  # Get the backend used for new connections.
  def self.backend
    @@backend
  end
  
  # Set the backend, which defaults to Net::LDAP. See MockLDAP.
  def self.backend=(backend)
    @@backend = backend
    @@connection = nil
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
  
  def self.dn_to_domain(dn)
    dn.split(/,?dc=/)[1..-1].join('.')
  end
  
  module Search
    
    def base_domain
      Directory.dn_to_domain(base)
    end
    
    def find_by_dn(dn, &block)
      search(:base => dn, :scope => Net::LDAP::SearchScope_BaseObject, &block)
    end
    
    def find_by_dn_with_attr(dn, attribute, &block)
      search(:base => dn,
             :filter => Net::LDAP::Filter.pres(attribute), :scope => Net::LDAP::SearchScope_BaseObject,
             &block)
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
    
    def find_users_by_mail(mail, &block)
      search(:base => "ou=users,#{base}", :filter => Net::LDAP::Filter.eq('mail', "#{mail}"), &block)
    end
    
    def find_user_by_meetalias(mail, &block)
      search(:base => "ou=users,#{base}", :filter => Net::LDAP::Filter.eq('meetalias', "#{mail}"), &block)
    end
    
    def all_new_users(&block)
      search(:base => "ou=newusers,#{base}", :filter => Net::LDAP::Filter.pres('cn'), &block)
    end
    
    def find_new_user_by_cn(cn, &block)
      search(:base => "ou=newusers,#{base}", :filter => Net::LDAP::Filter.eq('cn', "#{cn}"), &block)
    end
    
    def find_new_user_by_mail(mail, &block)
      search(:base => "ou=newusers,#{base}", :filter => Net::LDAP::Filter.eq('mail', "#{mail}"), &block)
    end
    
    def find_new_user_by_uid(uid, &block)
      search(:base => "ou=newusers,#{base}", :filter => Net::LDAP::Filter.eq('uid', "#{uid}"), &block)
    end

    def next_user_uidnumber
      search(:base => "ou=users,#{base}",
             :filter => Net::LDAP::Filter.pres('uid'),
             :attributes => 'uidnumber').map { |entry| entry[:uidnumber].first.to_i } .max + 1
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
    
    def find_group_by_meetalias(mail, &block)
      search(:base => "ou=groups,#{base}", :filter => Net::LDAP::Filter.eq('meetalias', "#{mail}"), &block)
    end
    
    def find_app_by_url(url, &block)
      search(:base => "ou=apps,#{base}", :filter => Net::LDAP::Filter.eq('labeleduri', "#{url}"), &block)
    end
    
  end
  
end
