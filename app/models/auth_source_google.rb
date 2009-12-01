# redMine - project management software
# Copyright (C) 2009 Todd A. Fisher
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'google/base'

# load source domains from gauth.yml
#

class AuthSourceGoogle < AuthSource 
  def authenticate(email, password)
    attrs = nil
    $_auth_sources ||= YAML.load_file("#{RAILS_ROOT}/config/auth_sources.yml")
    source_domain = $_auth_sources['sources'].find {|s| logger.debug(s); email.match(/^.*@#{s}$/) }
    if source_domain
      begin
        # see if we can authenticate using google
        auth_base = Google::Base.establish_connection(email,password)
      rescue OpenSSL::SSL::SSLError => e
        logger.error(e.message + "\n" + e.backtrace.join("\n"))
        auth_base = nil
      rescue Google::LoginError => e
        logger.error(e.message + "\n" + e.backtrace.join("\n"))
        auth_base = nil
      rescue => e
        logger.error(e.message + "\n" + e.backtrace.join("\n"))
        auth_base = nil
      end
      if auth_base
        user_name = email.gsub(/@#{source_domain}/,'').gsub(/\./,' ').titleize

        attrs = [
         :mail                  => email, 
         :login                 => user_name,
         :firstname            => user_name.gsub(/\s.*$/,''),
         :lastname             => user_name.gsub(/^.*\s/,''),
         :auth_source_id        => self.id,
         :password              => password,
         :password_confirmation => password,
         :admin                 => true
        ]

        attrs

      end
    end
    attrs
  end

end
