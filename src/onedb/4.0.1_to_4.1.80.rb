# -------------------------------------------------------------------------- #
# Copyright 2002-2013, OpenNebula Project (OpenNebula.org), C12G Labs        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'fileutils'
require 'rexml/document'
require 'openssl'


module Migrator
    def db_version
        "4.1.80"
    end

    def one_version
        "OpenNebula 4.1.80"
    end

    def up

        begin
            FileUtils.cp("#{VAR_LOCATION}/.one/sunstone_auth",
                "#{VAR_LOCATION}/.one/onegate_auth", :preserve => true)

            FileUtils.cp("#{VAR_LOCATION}/.one/sunstone_auth",
                "#{VAR_LOCATION}/.one/oneflow_auth", :preserve => true)
        rescue
            puts "Error trying to copy #{VAR_LOCATION}/.one/sunstone_auth "<<
                "to #{VAR_LOCATION}/.one/onegate_auth and #{VAR_LOCATION}/.one/oneflow_auth."
            puts "Please copy the files manually."
        end

        @db.run "ALTER TABLE user_pool RENAME TO old_user_pool;"
        @db.run "CREATE TABLE user_pool (oid INTEGER PRIMARY KEY, name VARCHAR(128), body MEDIUMTEXT, uid INTEGER, gid INTEGER, owner_u INTEGER, group_u INTEGER, other_u INTEGER, UNIQUE(name));"

        @db.fetch("SELECT * FROM old_user_pool") do |row|
            doc = REXML::Document.new(row[:body])

            doc.root.each_element("TEMPLATE") do |e|
                e.add_element("TOKEN_PASSWORD").text =
                    OpenSSL::Digest::SHA1.hexdigest( rand().to_s )
            end

            @db[:user_pool].insert(
                :oid        => row[:oid],
                :name       => row[:name],
                :body       => doc.root.to_s,
                :uid        => row[:oid],
                :gid        => row[:gid],
                :owner_u    => row[:owner_u],
                :group_u    => row[:group_u],
                :other_u    => row[:other_u])
        end

        @db.run "DROP TABLE old_user_pool;"

        ########################################################################
        # Feature #1613
        ########################################################################

        @db.run "ALTER TABLE datastore_pool RENAME TO old_datastore_pool;"
        @db.run "CREATE TABLE datastore_pool (oid INTEGER PRIMARY KEY, name VARCHAR(128), body MEDIUMTEXT, uid INTEGER, gid INTEGER, owner_u INTEGER, group_u INTEGER, other_u INTEGER, cid INTEGER, UNIQUE(name));"

        @db.fetch("SELECT * FROM old_datastore_pool") do |row|
            doc = REXML::Document.new(row[:body])

            doc.root.add_element("TOTAL_MB").text = "0"
            doc.root.add_element("FREE_MB").text = "0"
            doc.root.add_element("USED_MB").text = "0"

            @db[:datastore_pool].insert(
                :oid        => row[:oid],
                :name       => row[:name],
                :body       => doc.root.to_s,
                :uid        => row[:uid],
                :gid        => row[:gid],
                :owner_u    => row[:owner_u],
                :group_u    => row[:group_u],
                :other_u    => row[:other_u],
                :cid        => row[:cid])
        end

        @db.run "DROP TABLE old_datastore_pool;"

        return true
    end
end