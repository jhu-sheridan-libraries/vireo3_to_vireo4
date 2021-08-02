require 'pg'

require_relative 'MigrateGlobal.rb'
#require_relative 'SiteSpecific.rb'
require_relative 'SiteSpecific.rb'

module VIREO
  module Map
    class << self
      # Since vireo4 now lets administrators design hierarchical organizational structures from which other
      # organizations can inherit, many institutions reconfigure the way vireo represents their organization
      # over what was expressed in vireo3.

      # The initial organizational structure can be expressed in src/main/resources/organization/SYSTEM_Organization_Definition.json
      # The vireo4 organization can alternatively be expressed here.


      def buildOrg()
        institution_id = 0
        # This method will fill in the tables:
        #  organization, organization_children_organizations, and organization_aggregate_workflow_steps

        # update managed_configuration settings
        # setManagedConfiguration('hierarchical','true')
        # setManagedConfiguration('submissions_open','true')
        # setManagedConfiguration('allow_multiple_submissions','true')

        # Organization categories are set up upon startup.
        # These are configured in SYSTEM_Organization_Definition.json and are
        # stored in organization_category

        orgCat = getOrgCategory()
        college_category_id = orgCat.key("College")
        program_category_id = orgCat.key("Program")
        degree_category_id = orgCat.key("Degree")

        ####################
        # Correct the name of the institution instead of accepting the default value, doing this will return the institution_id.
        ####################
        # institution_id = renameInstitution(orgCat,"My Personal University")

        ####################
        # Create a college level entry called 'Graduate School' which is part of this institution.
        # The first parameter sets if it will allow sub organizations below it - true or false
        # The second parameter is the name.
        # The third parameter declares the category base on the orgCat key above.
        # Set it to be part of the institution declared above by setting the last parameter to institution_id
        ####################
        # college_id = createOrganization("t","Graduate School",college_category_id,institution_id)
        # createOrgChildrenOrg(institution_id,college_id)
        # createOrgAWS(college_id)

        ####################
        # Create another college level entry called 'Honors College.'
        ####################
        # college_id = createOrganization("t","Honors College",college_category_id,institution_id)
        # createOrgChildrenOrg(institution_id,college_id)
        # createOrgAWS(college_id)

        # Give Honors College an 'Honors Program' program.
        #	program_id = createOrganization("t","Honors Program",program_category_id,college_id)
        #	createOrgChildrenOrg(college_id,program_id)
        #	createOrgAWS(program_id)

        #institution_id = siteSpecificOrg()
        institution_id = siteSpecificOrg()
      end

      def useV3CollegesForOrganization(parent_organization_id, org_level_id, allow_submissions)
        collegeSelect = "SELECT id,name,displayorder FROM college;"
        v3collegeRS = VIREO::CON_V3.exec collegeSelect
        category_id = 1
        parent_organization_id = 1
        college_id_list = Array.new
        puts "V3 COLLEGE LIST"
        v3collegeRS.each do |row|
          # puts " ROW "+row.to_s
          begin
            collegeName = VIREO::CON_V4.escape_string(row['name'])
            puts "V3 COLL COLLNAME " + collegeName
            college_id = createOrganization(allow_submissions, collegeName,
                                            org_level_id, parent_organization_id)
            createOrgChildrenOrg(parent_organization_id, college_id)
            createOrgAWS(college_id)
            college_id_list << college_id
          rescue StandardError => e
            puts "COLL EXCEPTION " + e.message
          end
        end
        puts "COLLEGE ID LIST " + college_id_list.to_s + "\n"
      end

      def setManagedConfiguration(name, value)
        if (VIREO::REALRUN)
          begin
            hierSelect = "SELECT name FROM managed_configuration WHERE name = '" + name + "';"
            v4hierSel = VIREO::CON_V4.exec hierSelect
            if ((v4hierSel != nil) && (v4hierSel.count > 0))
              hierUpdate = "UPDATE managed_configuration SET value = '%s' WHERE name = '%s';" % [value, name]
              VIREO::CON_V4.exec hierUpdate
            else
              hierInsert = "INSERT INTO managed_configuration (id,name,type,value) VALUES (DEFAULT,'%s','%s','%s');" % [name,
                                                                                                                        'application', value]
              VIREO::CON_V4.exec hierInsert
            end
          rescue StandardError => e
            puts "HIER EXCEPTION " + e.message
          end
        end
      end

      def getOrgCategory()
        orgCatSelect = "SELECT id,name FROM organization_category;"
        v4orgCatRS = VIREO::CON_V4.exec orgCatSelect
        orgCat = Hash.new
        v4orgCatRS.each do |oc|
          begin
            orgCat[oc['id']] = oc['name'].to_s
          rescue StandardError => e
            puts "COLL EXCEPTION " + e.message
          end
        end
        return orgCat
      end

      def renameInstitution(orgCat, orgName)
        inst_cat = orgCat.key("System")
        puts "SYST IND " + inst_cat.to_s
        instUpdate = "UPDATE organization SET name = '%s' WHERE category_id = %s RETURNING id;" % [orgName, inst_cat]
        begin
          v4_upd = VIREO::CON_V4.exec instUpdate
        rescue StandardError => e
          puts "EXCEPTION INSTITUTION RENAME " + e.message
        end
        org_id = v4_upd[0]['id'].to_i
        return org_id
      end

      def createOrganizationCategory(name)
        name = VIREO::CON_V4.escape_string(name)
        organizationCatFind = "SELECT id FROM organization_category WHERE name='%s';" % [name]
        v4_organizationCatF = VIREO::CON_V4.exec organizationCatFind
        if ((v4_organizationCatF != nil) && (v4_organizationCatF.count > 0))
          v4_id = v4_organizationCatF[0]['id'].to_i
          puts "\tFOUND ORGANIZATION ALREADY IN V4 " + v4_id.to_s
          return v4_id
        else
          v4_id = 0
          if (VIREO::REALRUN)
            organizationCatInsert = "INSERT INTO organization_category (id,name) VALUES(DEFAULT,'%s') RETURNING id;" % [name]
            v4_organizationCatRS = VIREO::CON_V4.exec organizationCatInsert
            v4_id = v4_organizationCatRS[0]['id'].to_i
            puts "\tCREATED NEW ORGANIZATION CAT IN V4 " + v4_id.to_s
          else
            puts "\tDRYRUN CREATE ORGANIZATION CAT NEW IN V4"
          end
          return v4_id
        end
      end

      def createOrganization(accept_sub, name, category_id, parent_organization_id)
        puts "NAME " + name + " CAT " + category_id.to_s + " PAR " + parent_organization_id.to_s
        # UTILITY FOR USE BY fillOrganization
        # category 7system,6admingroup,5program,4major,3department,2degree,1college
        name = VIREO::CON_V4.escape_string(name)
        organizationFind = "SELECT id FROM organization WHERE accepts_submissions='%s' AND name='%s' AND category_id=%s AND parent_organization_id=%s;" % [
          accept_sub, name, category_id, parent_organization_id
        ]
        v4_organizationF = VIREO::CON_V4.exec organizationFind
        if ((v4_organizationF != nil) && (v4_organizationF.count > 0))
          v4_id = v4_organizationF[0]['id'].to_i
          puts "\tFOUND ORGANIZATION ALREADY IN V4 " + v4_id.to_s
          return v4_id
        else
          v4_id = 0
          if (VIREO::REALRUN)
            organizationInsert = "INSERT INTO organization (id,accepts_submissions,name,category_id,parent_organization_id) VALUES(DEFAULT,'%s','%s',%s,%s) RETURNING id;" % [
              accept_sub, name, category_id, parent_organization_id
            ]
            v4_organizationRS = VIREO::CON_V4.exec organizationInsert
            v4_id = v4_organizationRS[0]['id'].to_i
            puts "\tCREATED NEW ORGANIZATION IN V4 " + v4_id.to_s
          else
            puts "\tDRYRUN CREATE ORGANIZATION NEW IN V4"
          end
          return v4_id
        end
      end

      def createOrgChildrenOrg(parentorg_id, org_id)
        # UTILITY FOR USE BY fillOrganization
        organizationcoFind = "SELECT * FROM organization_children_organizations WHERE organization_id=%s AND children_organizations_id=%s;" % [
          parentorg_id, org_id
        ]
        v4_organizationcoF = VIREO::CON_V4.exec organizationcoFind
        if ((v4_organizationcoF != nil) && (v4_organizationcoF.count > 0))
          v4_orgco = v4_organizationcoF[0] != nil
          puts "\t\tFOUND ORGCO NEW IN V4 " + v4_organizationcoF[0].to_s
        else
          if (VIREO::REALRUN)
            organizationcoInsert = "INSERT INTO organization_children_organizations (organization_id,children_organizations_id) VALUES(%s,%s);" % [
              parentorg_id, org_id
            ]
            VIREO::CON_V4.exec organizationcoInsert
            puts "\ttCREATED ORG_CHILDREN_ORG " + organizationcoInsert
          else
            puts "\ttDRYRUN CREATED ORG_CHILDREN_ORG "
          end
        end
      end

      def createOrgAWS(org_id)
        # #get array of workflow_steps for organization_id or its parent
        wfsSelect = "SELECT id,instructions,name,overrideable FROM workflow_step WHERE originating_organization_id = 1;" # % [organization_id]
        ## Eventually work up the hierarchy to find a valid org
        v4_wfsRS = VIREO::CON_V4.exec wfsSelect
        v4_wfsRS.each_with_index do |wfs, wfs_indx|
          organizationawsFind = "SELECT * FROM organization_aggregate_workflow_steps WHERE organization_id=%s AND aggregate_workflow_steps_id=%s AND aggregate_workflow_steps_order=%s;" % [
            org_id.to_i, wfs['id'].to_i, wfs_indx
          ]
          v4_organizationawsF = VIREO::CON_V4.exec organizationawsFind
          if ((v4_organizationawsF != nil) && (v4_organizationawsF.count > 0))
            v4_orgaws = v4_organizationawsF[0].to_s
            puts "\t\tFOUND ORGAWS IN V4 " + v4_orgaws.to_s
          else
            if (VIREO::REALRUN)
              organizationawsInsert = "INSERT INTO organization_aggregate_workflow_steps (organization_id,aggregate_workflow_steps_id,aggregate_workflow_steps_order) VALUES(%s,%s,%s);" % [
                org_id.to_i, wfs['id'].to_i, wfs_indx
              ]
              puts "\t\tCREATING ORG_AWS " + organizationawsInsert
              begin
                VIREO::CON_V4.exec organizationawsInsert
              rescue StandardError => e
                puts "\t\tORG INSERT EXCEPTION " + e.message
              end
            else
              puts "\t\tDRYRUN CREATED ORG_AWS"
            end
          end
        end
      end
    end
  end
end

puts "\n\nORGANIZATION BEGIN====================================="
puts VIREO::Map.buildOrg().to_s
puts "ORGANIZATION END =====================================\n"
