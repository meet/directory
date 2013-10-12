module Directory
  
  # Represents a user.
  class User
    
    # Find all users.
    def self.all
      return Directory.connection.all_users.map { |entry| new(entry) }
    end
    
    # Find a user by username.
    def self.find(username)
      Directory.connection.find_user_by_uid(username) do |entry|
        return new(entry)
      end
      return false
    end
    
    # Find all users matching a simple query.
    def self.search(query)
      return Directory.connection.find_users_by_match(query).map { |entry| new(entry) }
    end
    
    attr_reader :dn, :username, :first_name, :last_name, :name, :mail_forward, :mail_aliases, :enabled, :mail_destination_inbox
    
    def initialize(entry)
      @dn = entry[:dn].first
      @username = entry[:uid].first
      @first_name = entry[:givenname].first
      @last_name = entry[:sn].first
      @name = entry[:cn].first || "#{@first_name} #{@last_name}"
      @mail_forward = entry[:mail].first
      @mail_destination_inbox = entry[:destinationindicator].first == 'inbox'
      @mail_aliases = entry[:meetalias]
      @enabled = entry[:shadowexpire].empty?
      @groups = nil
      @passworded = nil
    end
    
    def enabled=(enabled)
      Directory.connection.delete_attribute(dn, :shadowexpire)
      if not enabled
        Directory.connection.add_attribute(dn, :shadowexpire, '0')
      end
      reinitialize!
    end
    
    def groups
      @groups ||= Group.find_by_member(username)
    end
    
    def mail
      "#{username}@#{Directory.dn_to_domain(dn)}"
    end
    
    def mail_forward=(mail_forward)
      Directory.connection.replace_attribute(dn, :mail, mail_forward)
      reinitialize!
    end
    
    def mail_destination_inbox=(mail_inbox)
      Directory.connection.delete_attribute(dn, :destinationindicator)
      Directory.connection.add_attribute(dn, :destinationindicator, "inbox") if mail_inbox
      reinitialize!
    end
    
    def passworded
      @passworded = ! Directory.connection.find_by_dn_with_attr(dn, :userpassword).empty? if @passworded.nil?
      @passworded
    end
    
    # Set a new password by hashing the given plaintext.
    def password=(password)
      salt = (1..4).collect { |i| (rand(126-32+1)+32).chr }.to_s
      hashed = '{SSHA}'+Base64.encode64(Digest::SHA1.digest(password+salt)+salt).chomp
      Directory.connection.replace_attribute(dn, :userpassword, hashed)
    end
    
    # Return true iff this User represents the same User as the other.
    def is?(other)
      username == other.username
    end
    
    # Return true iff this user is an admin, or this user is a manager and the other is not an admin.
    def admin?(other)
      if groups.find { |g| g.groupname == 'admins' }
        return true
      elsif groups.find { |g| g.groupname == 'managers' } and not other.groups.find { |g| g.groupname == 'admins' }
        return true
      end
      return false
    end
    
    # Return true iff this user is a manager.
    def manager?
      groups.find { |g| g.groupname == 'admins' || g.groupname == 'managers' } != nil
    end
    
    # ActiveRecord methods
    
    def self.model_name
      ActiveModel::Name.new(self)
    end
    
    def persisted?
      @dn != nil
    end
    
    def to_key
      persisted? ? [ username ] : nil
    end
    
    def to_s
      username
    end
    
    def as_json(options = nil)
      { :username => username, :name => name }
    end
    
    private
      
      def reinitialize!
        Directory.connection.find_by_dn(dn) { |entry| initialize(entry) }
      end
      
  end
  
end
