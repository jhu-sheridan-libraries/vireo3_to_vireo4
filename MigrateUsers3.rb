require 'pg'

require_relative 'MigrateGlobal.rb'

=begin
mapPersonToWeaverUsers
The V3.person table is copied to V4.weaver_users following the creation of current and permanent V4.address records and V4.contact_info records which are linked to from V4.weaver_users.

Further work could be put into parsing the open text form of V3.person postaladdress fields for better representation in V4.

Entries for each V4.weaver_user are made in the V4.named_search_filter_group and V4.user_settings
=end

module VIREO
  module Map
    class << self
      # #WEAVER USERS
      def mapPersonToWeaverUsers()
        totalExpected = 0
        personCount = 'SELECT COUNT(*) FROM person;'
        v3pcRS = VIREO::CON_V3.exec personCount
        begin
          v3pcRS.each do |row|
            totalExpected = row['count'].to_i
          end
        end

        # CREATE ADDRESS AND CONTACTINFO
        personSelect = 'SELECT id,displayname,birthyear,email,firstname,lastname,middlename,netid,orcid,0,passwordhash,role,0,email,currentphonenumber,permanentphonenumber,currentpostaladdress,permanentpostaladdress,permanentemailaddress FROM person;'
        completed = 0
        failed = 0
        v3personRS = VIREO::CON_V3.exec personSelect
        puts "V3 WEAVER_USERS LIST OF " + v3personRS.count.to_s + " ==========================================="
        v3personRS.each do |row|
          begin
            puts "################"
            puts "V3 WEAVER_USERS ID " + row['id'].to_s + " EMAIL " + row['email'].to_s
            weaverusers_id = createWeaverUsers(row)
            # if(row['id'].to_i!=weaverusers_id)
            #	puts "MISMATCH V3 "+row['id'].to_s+" V4 "+weaverusers_id.to_s
            # else
            #	puts "MATCH V3 "+row['id'].to_s+" V4 "+weaverusers_id.to_s
            # end

            curr_address_id = createAddress(0, row['currentpostaladdress'])
            puts "  CURR ADDR ID " + curr_address_id.to_s
            curr_contactinfo_id = createContactInfo(0, row['email'], row['currentphonenumber'], curr_address_id,
                                                    weaverusers_id)
            puts "  CURR CONT INFO ID " + curr_contactinfo_id.to_s
            perm_address_id = createAddress(1, row['permanentpostaladdress'])
            puts "  PERM ADDR ID " + perm_address_id.to_s
            puts "PA " + row['permanentemailaddress'].to_s
            puts "ROW " + row.to_s
            permanent_email = row['permanentemailaddress']
            email = row['email']
            if(firstname!=nil)
              firstname = VIREO::CON_V4.escape_string(firstname)
            end
            if(lastname!=nil)
              lastname = VIREO::CON_V4.escape_string(lastname)
            end
            if(permanent_email!=nil)
              permanent_email = VIREO::CON_V4.escape_string(permanent_email)
            end
            if(email!=nil)
              email = VIREO::CON_V4.escape_string(email)
            end

            perm_contactinfo_id = createContactInfo(1, permanent_email, row['permanentphonenumber'],
                                                    perm_address_id, weaverusers_id)
            puts "  PERM CONT INFO ID " + perm_contactinfo_id.to_s


            createUserSettings(weaverusers_id, email, row['firstname'], row['lastname'])
            active_filter_id = createNamedSearchFilterGroup(weaverusers_id);
            weaverusers_id = updateWeaverUsers(weaverusers_id, curr_contactinfo_id, perm_contactinfo_id,
                                               active_filter_id)
            # puts "WID "+weaverusers_id.to_s
            col_array = [42, 3, 1, 43, 46, 21, 47, 48, 32, 33]
            createWeaverUsersSubmissionViewColumns(weaverusers_id, col_array)
            completed += 1
            puts "################"
          rescue StandardError => e
            failed += 1
            puts "EXCEPTION " + e.message
          end
          puts "TOTAL EXPECTED " + totalExpected.to_s + " COMPLETED " + completed.to_s + " FAILED " + failed.to_s
        end
        return { "completed": completed, "failed": failed }
      end

      def createWeaverUsersSubmissionViewColumns(weaverusers_id, col_array)
        col_array.each_with_index do |c, indx|
          wusvcFind = "SELECT * FROM weaver_users_submission_view_columns WHERE user_id=%s AND submission_view_columns_id=%s AND submission_view_columns_order=%s;" % [
            weaverusers_id.to_s, c.to_s, indx.to_s
          ]
          v4_wusvcF = VIREO::CON_V4.exec wusvcFind
          if ((v4_wusvcF != nil) && (v4_wusvcF.count.to_i > 0))
            v4_wid = v4_wusvcF[0]['submission_view_columns_order'].to_i
            puts "    V4 WUSVC FOUND COL_ORDER " + v4_wid.to_s
          else
            if (VIREO::REALRUN)
              begin
                wusvcInsert = "INSERT INTO weaver_users_submission_view_columns VALUES(%s,%s,%s);" % [weaverusers_id.to_s,
                                                                                                      c.to_s, indx.to_s]
                puts "       V4 WUSVC QUERY " + wusvcInsert.to_s
                v4_wusvcRS = VIREO::CON_V4.exec wusvcInsert
                puts "       V4 WUSVC CREATED ID " + weaverusers_id.to_s
              rescue StandardError => e
                puts "       V4 WUSVC EXCEPTION " + e.message
              end
            end

          end
        end
      end

      def createAddress(indx, addrText)
        # if(addrText == nil)
        #	puts "    V4 ADDRESS "+indx+" IS EMPTY "
        #	return 0
        # end
        # doing simple parsing of addresses for demo purposes but we could use an api like
        #	https://github.com/openvenues/libpostal or https://geonames.org
        addr_parts = addrText.to_s.split("\r")
        addr_id = 'null'
        if (addr_parts.length == 4)
          addr_line1 = addr_parts[0].strip()
          addr_line2 = addr_parts[1].strip()
          citystatezip = addr_parts[2].strip()
          country = addr_parts[3].strip()
        elsif (addr_parts.length == 3)
          addr_line1 = addr_parts[0].strip()
          addr_line2 = addr_parts[1].strip()
          citystatezip = addr_parts[2].strip()
        elsif (addr_parts.length == 2)
          addr_line1 = addr_parts[0].strip()
          citystatezip = addr_parts[1].strip()
        end
        city = ""
        state = ""
        postal_code = ""
        if (citystatezip)
        end
        if (addr_line1 != nil)
          addr_line1 = VIREO::CON_V4.escape_string(addr_line1)
        end
        if (addr_line2 != nil)
          addr_line2 = VIREO::CON_V4.escape_string(addr_line2)
        end
        if (citystatezip != nil)
          citystatezip = VIREO::CON_V4.escape_string(citystatezip)
        end
        if (country != nil)
          country = VIREO::CON_V4.escape_string(country)
        end

        address_find = "SELECT * FROM address WHERE address1='%s' AND address2='%s' AND city='%s' AND country='%s' AND postal_code='%s' AND state='%s';" % [
          addr_line1, addr_line2, city, country, postal_code, state
        ]
        v4_addressF = VIREO::CON_V4.exec address_find
        puts "      V4 ADDR COUNT " + v4_addressF.count.to_s
        if ((v4_addressF != nil) && (v4_addressF.count > 0))
          # v4_aid = v4_addressF[indx]['id'].to_i
          v4_aid = v4_addressF[0]['id'].to_i
          puts "      V4 ADDRESS FOUND ID " + v4_aid.to_s
          return v4_aid
        else
          addr_id = 0
          if (VIREO::REALRUN)
            address_stmt = "INSERT INTO address VALUES(DEFAULT,'%s','%s','%s','%s','%s','%s') RETURNING id;" % [addr_line1,
                                                                                                                addr_line2, city, country, postal_code, state]
            v4_addressRS = VIREO::CON_V4.exec address_stmt
            addr_id = v4_addressRS[0]['id'].to_i
          end
          puts "      V4 ADDRESS CREATED ID " + addr_id.to_s
          return addr_id
        end
      end

      def createContactInfo(indx, email, phonenumber, address_id, weaverusers_id)
        puts "CCI " + weaverusers_id.to_s
        puts " IDX " + indx.to_s
        if (email != nil)
          puts " EM " + email
        end
        contactinfoInWeaver = "SELECT current_contact_info_id FROM weaver_users WHERE id=%s;" % [weaverusers_id]
        if (indx == 1)
          # puts "  PERMANENT"
          contactinfoInWeaver = "SELECT permanent_contact_info_id FROM weaver_users WHERE id=%s;" % [weaverusers_id]
        else
          # puts "  CURRENT"
        end
        existCI = VIREO::CON_V4.exec contactinfoInWeaver
        contact_info_id = 0;
        if ((existCI != nil) && (existCI.count.to_i > 0))
          if (indx == 0)
            puts "      V4 CURR_CONTACT_INFO FOUND WITH ID " + existCI[0]['current_contact_info_id'].to_s
            contact_info_id = existCI[0]['current_contact_info_id'].to_i
          else
            puts "      V4 PERM_CONTACT_INFO FOUND WITH ID " + existCI[0]['permanent_contact_info_id'].to_s
            contact_info_id = existCI[0]['permanent_contact_info_id'].to_i
          end
        else
          puts "			ALREADY EXISTS"
        end

        if ((contact_info_id != nil) && (contact_info_id > 0))
        else
          ci_id = 0
          if (VIREO::REALRUN)
            contactinfoInsert = "INSERT INTO contact_info VALUES(DEFAULT,'%s','%s',%s) RETURNING id;" % [email, phonenumber,
                                                                                                         address_id]
            if (address_id == 0)
              contactinfoInsert = "INSERT INTO contact_info VALUES(DEFAULT,'%s','%s') RETURNING id;" % [email,
                                                                                                        phonenumber]
            end
            v4_contactinfoRS = VIREO::CON_V4.exec contactinfoInsert
            ci_id = v4_contactinfoRS[0]['id'].to_i
          end
          if (indx == 0)
            puts "  V4 CURR_CONTACT_INFO CREATED ID " + ci_id.to_s
          else
            puts "  V4 PERM_CONTACT_INFO CREATED ID " + ci_id.to_s
          end
          return ci_id
        end
        return 0
      end

      def createUserSettings(weaverusers_id, email, firstname, lastname)
        begin

          userSettingsFind = "SELECT * FROM user_settings WHERE user_id=%s AND value='%s' AND setting='%s';" % [
            weaverusers_id, (firstname + ' ' + lastname), "displayName"
          ]
          v4_usF = VIREO::CON_V4.exec userSettingsFind
          if ((v4_usF != nil) && (v4_usF.count.to_i > 0))
            v4_usFid = v4_usF[0]['user_id'].to_i
          # puts "    V4 USER_SETTINGS 'displayName' FOUND FOR USER_ID "+v4_usFid.to_s
          else
            if (VIREO::REALRUN)
              userSettingsInsert = "INSERT INTO user_settings VALUES(%s,'%s','%s');" % [weaverusers_id,
                                                                                        (firstname + ' ' + lastname), "displayName"]
              VIREO::CON_V4.exec userSettingsInsert
            end
            # puts "    V4 USER_SETTINGS 'displayName' CREATED FOR USER_ID "+weaverusers_id.to_s
          end

          userSettingsFind = "SELECT * FROM user_settings WHERE user_id=%s AND value='%s' AND setting='%s';" % [
            weaverusers_id, email, "preferedEmail"
          ]
          v4_usF = VIREO::CON_V4.exec userSettingsFind
          if ((v4_usF != nil) && (v4_usF.count.to_i > 0))
            v4_usFid = v4_usF[0]['user_id'].to_i
          # puts "    V4 USER_SETTINGS 'preferedEmail' FOUND ID "+v4_usFid.to_s
          else
            if (VIREO::REALRUN)
              userSettingsInsert = "INSERT INTO user_settings VALUES(%s,'%s','%s');" % [weaverusers_id, email,
                                                                                        "preferedEmail"]
              VIREO::CON_V4.exec userSettingsInsert
            end
            # puts "    V4 USER_SETTINGS 'preferedEmail' CREATED FOR USER_ID "+weaverusers_id.to_s
          end

          userSettingsFind = "SELECT * FROM user_settings WHERE user_id=%s AND value='%s' AND setting='%s';" % [
            weaverusers_id, weaverusers_id.to_s, "id"
          ]
          v4_usF = VIREO::CON_V4.exec userSettingsFind
          if ((v4_usF != nil) && (v4_usF.count.to_i > 0))
            v4_usFid = v4_usF[0]['user_id'].to_i
          # puts "    V4 USER_SETTINGS 'id' FOUND ID "+v4_usFid.to_s
          else
            if (VIREO::REALRUN)
              userSettingsInsert = "INSERT INTO user_settings VALUES(%s,'%s','%s');" % [weaverusers_id, weaverusers_id.to_s,
                                                                                        "id"]
              VIREO::CON_V4.exec userSettingsInsert
            end
            # puts "    V4 USER_SETTINGS 'id' CREATED FOR USER_ID "+weaverusers_id.to_s
          end
        rescue StandardError => e
          puts "USER SETTINGS EXCEPTION " + e.message
        end
      end

      def createNamedSearchFilterGroup(weaverusers_id)
        columns_flag = false
        name = nil
        public_flag = false
        sort_column_title = nil
        sort_direction = nil
        umi_release = false
        begin
          cnsfgFind = "SELECT id FROM named_search_filter_group WHERE columns_flag='%s' AND name='%s' AND public_flag='%s' AND umi_release='%s' AND user_id='%s';" % [
            columns_flag, name, public_flag, umi_release, weaverusers_id
          ]
          v4_cnsfgF = VIREO::CON_V4.exec cnsfgFind
          if ((v4_cnsfgF != nil) && (v4_cnsfgF.count.to_i > 0))
            v4_cnsfgid = v4_cnsfgF[0]['id'].to_i
            puts "    V4 NAMED_SEARCH_FILTER_GROUP FOUND ID " + v4_cnsfgid.to_s
            return v4_cnsfgid
          else
            cnsfg_id = 0
            if (VIREO::REALRUN)
              #cnsfgInsert = "INSERT INTO named_search_filter_group (id,columns_flag,name,public_flag,sort_column_title,sort_direction,umi_release,user_id) VALUES(DEFAULT,'%s','%s','%s','%s','%s','%s',%s) RETURNING id;" % [
              #  columns_flag, name, public_flag, sort_column_title,sort_direction,umi_release, weaverusers_id
              #]
              umi_release = false
              cnsfgInsert = "INSERT INTO named_search_filter_group (id,columns_flag,name,public_flag,umi_release,user_id) VALUES(DEFAULT,'%s','%s','%s','%s',%s) RETURNING id;" % [
                columns_flag, name, public_flag, umi_release, weaverusers_id
              ]

              v4_cnsfgRS = VIREO::CON_V4.exec cnsfgInsert
              cnsfg_id = v4_cnsfgRS[0]['id'].to_i
            end
            puts "    V4 NAMED_SEARCH_FILTER_GROUP CREATED ID " + cnsfg_id.to_s
            return cnsfg_id;
          end
        rescue StandardError => e
          puts "NSFG EXCEPTION " + e.message
          return -1;
        end
      end

      def createWeaverUsers(row)
        dtype = "User"
        wu_id = row['id']
        birthyear = row['birthyear']
        if (birthyear == nil)
          birthyear = 'null'
        end

        v3role = row['role']
        v4role = "ROLE_STUDENT";
        if (v3role == 2)
          v4role = "ROLE_REVIEWER"
        elsif (v3role == 3)
          v4role = "ROLE_MANAGER"
        elsif (v3role == 4)
          v4role = "ROLE_ADMIN"
        end

        page_size = 10

        pwdh = row['passwordhash']
        if (pwdh == nil)
          pwdh = 'null'
        end

        orcid = row['orcid']
        if (orcid == nil)
          orcid = 'null'
        end
        email = row['email']
        if (email != nil)
          email = VIREO::CON_V4.escape_string(email)
        end

        username = email

        firstname = row['firstname']
        if (firstname != nil)
          firstname = VIREO::CON_V4.escape_string(firstname)
        end
        lastname = row['lastname']
        if (lastname != nil)
          lastname = VIREO::CON_V4.escape_string(lastname)
        end
        middlename = row['middlename']
        if (middlename != nil)
          middlename = VIREO::CON_V4.escape_string(middlename)
        end

        weaver_users_find = "SELECT id FROM weaver_users WHERE id = %s;" % [wu_id]
        v4_weaverusersF = VIREO::CON_V4.exec weaver_users_find
        if ((v4_weaverusersF != nil) && (v4_weaverusersF.count.to_i > 0))
          v4_id = v4_weaverusersF[0]['id'].to_i
          weaver_users_findchange = "SELECT id FROM weaver_users WHERE dtype='%s' AND id=%s AND username='%s' AND birth_year=%s AND email='%s' AND first_name='%s' AND last_name='%s' AND middle_name='%s' AND netid='%s' AND orcid='%s' AND page_size=%s AND password='%s' AND role='%s';" % [
            dtype, wu_id.to_s, username, birthyear, email, firstname, lastname, middlename, row['netid'], orcid, page_size.to_s, pwdh, v4role
          ]
          weaver_users_findchange.gsub!("birth_year=null", "birth_year IS NULL")
          v4_weaverusersFC = VIREO::CON_V4.exec weaver_users_findchange
          v4_id_changed = v4_weaverusersFC[0]['id'].to_i
          if (v4_id_changed != nil)
            puts "  V4 WEAVER_USERS FOUND ID " + v4_id_changed.to_s + " UNCHANGED"
          else
            puts "  V4 WEAVER_USERS FOUND ID " + v4_id_changed.to_s + " NEEDS AN UPDATE"
          end
          return v4_id_changed.to_i
        else
          weaver_id = 0
          if (VIREO::REALRUN)
            weaver_users_stmt = "INSERT INTO weaver_users (dtype,id,username,birth_year,email,first_name,last_name,middle_name,netid,orcid,page_size,password,role) VALUES('%s',%s,'%s',%s,'%s','%s','%s','%s','%s','%s',%s,'%s','%s') RETURNING id;" % [
              dtype, wu_id.to_s, username, birthyear, email, firstname, lastname, middlename, row['netid'], orcid, page_size.to_s, pwdh, v4role
            ]
            # puts "V4 CREATING WEAVER USER "+weaver_users_stmt
            v4_weaverusersRS = VIREO::CON_V4.exec weaver_users_stmt
            weaver_id = v4_weaverusersRS[0]['id'].to_i
          end
          puts "  V4 WEAVER_USERS CREATED ID " + weaver_id.to_s
          return weaver_id
        end

        # return v4_id
      end

      def updateWeaverUsers(weaverusers_id, curr_contactinfo_id, perm_contactinfo_id, active_filter_id)
        # UPDATE WEAVER USERS WITH CONTACT (PERMANENT AND CURRENT).  DONE THIS WAY TO ENSURE ADDRESS AND CONTACT INFO IS DISTINCT IN RESPECTIVE TABLES
        weaver_users_find = "SELECT id FROM weaver_users WHERE current_contact_info_id=%s AND permanent_contact_info_id=%s AND active_filter_id=%s AND id= %s;" % [
          curr_contactinfo_id, perm_contactinfo_id, active_filter_id, weaverusers_id
        ]
        v4_weaverusersF = VIREO::CON_V4.exec weaver_users_find

        if ((v4_weaverusersF != nil) && (v4_weaverusersF.count.to_i > 0))
          v4_id = v4_weaverusersF[0]['id'].to_i
          puts "  V4 WEAVERUSERS NOT UPDATED FOR ID " + v4_id.to_s
          return v4_id.to_i
        else
          weaver_id = 0;
          if (VIREO::REALRUN)
            weaver_users_stmt = "UPDATE weaver_users SET current_contact_info_id=%s, permanent_contact_info_id=%s, active_filter_id=%s WHERE id= %s RETURNING id;" % [
              curr_contactinfo_id, perm_contactinfo_id, active_filter_id, weaverusers_id
            ]
            weaver_users_stmt.gsub!("current_contact_info_id=0,", "")
            weaver_users_stmt.gsub!("permanent_contact_info_id=0,", "")
            v4_weaverusersRS = VIREO::CON_V4.exec weaver_users_stmt
            weaver_id = v4_weaverusersRS[0]['id'].to_i
          end
          puts "V4 WEAVERUSERS WILL BE UPDATED IN V4"
          return weaver_id
        end
      end

      ###################
      ###################
      def checkForNullAdmins()
        # CREATE ADDRESS AND CONTACTINFO
        personSelect = "SELECT id,role FROM weaver_users WHERE username='null' OR username=NULL OR email='null' OR email=NULL;"
        v4personRS = VIREO::CON_V4.exec personSelect
        puts "V4 WEAVER_USERS LIST OF " + v4personRS.count.to_s + " ==========================================="
        role_admin = 0
        v4personRS.each do |row|
          begin
            puts "V4 WEAVER_USERS ID " + row['id'].to_s + " ROLE " + row['role'].to_s
            # SET TO STUDENT OR LOWER PRIV
            demoteUser(row['id'].to_s)
            role_admin += 1
          rescue StandardError => e
            puts "EXCEPTION " + e.message
          end
        end
        return role_admin
      end

      def demoteUser(id)
        nullUsersUpdate = "UPDATE weaver_users SET role='ROLE_STUDENT' WHERE id= %s;" % [id]
        v4_nullUsersRS = VIREO::CON_V4.exec nullUsersUpdate
      end
      ###################
      ###################

      def setAdmin()
        admin_list = VIREO::ADMIN_EMAIL
        admin_list.each do |email|
          personSelect = "SELECT id,role FROM weaver_users WHERE email = '%s';" % [email]
          v4personRS = VIREO::CON_V4.exec personSelect
          puts "V4 WEAVER_USERS LIST OF " + v4personRS.count.to_s + " ==========================================="
          id_str = ""
          v4personRS.each do |row|
            begin
              puts "V4 WEAVER_USERS ID " + row['id'].to_s + " ROLE " + row['role'].to_s
              if (row['id'] != nil)
                id_str = row['id'].to_s
                setAdminUpdate = "UPDATE weaver_users SET role='ROLE_ADMIN' WHERE id= %s;" % [id_str]
                v4_updateRS = VIREO::CON_V4.exec setAdminUpdate
              end
            rescue StandardError => e
              puts "EXCEPTION " + e.message
            end
          end
        end
      end
      ###################
    end
  end
end

puts "\n\nUSERS BEGIN =====================================\n"
puts VIREO::Map.mapPersonToWeaverUsers()
puts VIREO::Map.checkForNullAdmins()
puts VIREO::Map.setAdmin()
puts "USERS END =====================================\n"
