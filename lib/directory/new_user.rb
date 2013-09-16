module Directory
  
  # Represents a pending user.
  class NewUser
    
    include ActiveModel::Validations
    extend ActiveModel::Naming
    
    # Find all pending users.
    def self.all
      return Directory.connection.all_new_users.map { |entry| new({}, entry) }
    end
    
    # Find a pending user by key and update the returned instance.
    def self.find_and_update(key, attributes = {})
      Directory.connection.find_new_user_by_cn(key) do |entry|
        return new(attributes, entry)
      end
      return false
    end
    
    attr_reader :cn, :warnings
    attr_accessor :warned
    
    attr_accessor :requester, :primary_group, :username, :first_name, :last_name, :mail_forward, :mail_inbox
    
    validates_presence_of :requester, :primary_group, :username, :first_name, :last_name, :mail_forward
    validates_length_of :username, :in => 3..31
    validates_format_of :username, :with => /\A[a-z0-9]+\Z/, :message => 'must be lowercase letters only'
    validates_format_of :mail_forward, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
    validates_inclusion_of :mail_inbox, :in => [ true, false ], :message => 'preference required'
    
    validate do |user|
      if username && ! username.empty?
        [ :find_user_by_uid, :find_user_by_meetalias, :find_group_by_cn, :find_group_by_meetalias ].each do |search|
          Directory.connection.send(search, username) do
            errors.add(:username, "\"#{username}\" already in use")
          end
        end
      end
      
      if mail_forward =~ /@#{Directory.connection.base_domain}/i
        errors.add(:mail_forward, 'must be to an outside domain')
      end
      if cn.nil? && ! Directory.connection.find_new_user_by_mail(mail_forward).empty?
        errors.add(:mail_forward, 'already invited to create an account')
      end
      if ! Directory.connection.find_users_by_mail(mail_forward).empty?
        errors.add(:mail_forward, 'already in use')
      end
      
      if last_name.length > 1 && ! (people = User.search("#{first_name} #{last_name}")).empty?
        warnings[:similarly_named] = "user \"#{people.map(&:name).join(', ')}\" already has an account"
      end
      warnings[:first_name] = 'should be capitalized properly' unless first_name =~ /[[:upper:]][[:lower:]]/
      warnings[:last_name] = 'should be capitalized properly' unless last_name =~ /[[:upper:]][[:lower:]]/

      errors.add(:first_name, 'should not contain whitespace') if first_name =~ /\s/
      errors.add(:last_name, 'should not contain whitespace') if last_name =~ /\s/
    end
    
    def initialize(attributes = {}, entry = nil)
      @warnings = {}
      @warned = ''
      
      attributes.each do |name, value|
        send("#{name}=", value)
      end
      
      @mail_inbox = @mail_inbox == 'true' if @mail_inbox
      
      if entry
        @cn = entry[:cn].first
        @first_name = entry[:givenname].first
        @last_name = entry[:sn].first
        @mail_forward = entry[:mail].first
        Directory.connection.find_by_dn(entry[:manager].first) do |user|
          @requester = User.new(user) if user
        end
        @primary_group = entry[:ou].first
        @username = entry[:uid].first if entry[:uid]
      end
    end
    
    def dn
      "cn=#{cn},ou=newusers,#{Directory.connection.base}"
    end
    
    def name
      "#{first_name} #{last_name}"
    end
    
    def forewarned?
      valid? # required side-effect
      (warnings.stringify_keys.keys - warned.split(',')).empty?
    end
    
    def save_errors
      my_errors = errors
      my_errors = my_errors.reject { |attrib, msgs| [ :username ].include?(attrib) } if (username && username.empty?)
      my_errors = my_errors.reject { |attrib, msgs| [ :mail_inbox ].include?(attrib) } unless mail_inbox.present?
      #my_errors = my_errors.reject { |attrib, msgs| [ :username, :mail_inbox ].include?(attrib) }
      my_errors
    end
    
    def valid_to_save?
      forewarned? && save_errors.empty?
    end
    
    def valid_to_create?
      forewarned? && errors.empty?
    end
    
    def save
      @cn = SecureRandom.hex(8)
      attributes = {
        :objectclass => ['top', 'inetOrgPerson' ],
        :cn => cn,
        :givenname => first_name,
        :sn => last_name,
        :mail => mail_forward,
        :manager => requester.dn,
        :ou => primary_group}

      attributes[:uid] = username if (username && !username.empty?)
      attributes[:destinationindicator] = mail_inbox ? 'inbox' : nil if (mail_inbox.present?)

      Directory.connection.add(:dn => dn, :attributes => attributes) or raise Net::LDAP::LdapError, Directory.connection.get_operation_result.message
    end
    
    def create
      Directory.connection.add(:dn => "uid=#{username},ou=users,#{Directory.connection.base}", :attributes => {
        :objectclass => [ 'top', 'inetOrgPerson', 'posixAccount', 'shadowAccount' ],
        :uid => username,
        :cn => name,
        :givenname => first_name,
        :sn => last_name,
        :mail => mail_forward,
        :destinationindicator => mail_inbox ? 'inbox' : nil,
        :homedirectory => "/home/#{username}",
        :loginshell => '/bin/bash',
        :uidnumber => Directory.connection.next_user_uidnumber.to_s,
        :gidnumber => '1000'
      }) or raise Net::LDAP::LdapError, Directory.connection.get_operation_result.message
      Directory.connection.delete(:dn => dn)
      Directory.connection.add_attribute(Group.find(primary_group).dn, :memberuid, username)
      return User.find(username)
    end
    
    # ActiveRecord methods
    
    def persisted?
      cn != nil
    end
    
    def to_key
      [ cn ]
    end
    
  end
  
end
