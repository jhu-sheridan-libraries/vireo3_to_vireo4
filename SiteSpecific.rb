require 'pg'

require_relative 'MigrateGlobal.rb'

module VIREO
  module Map
    class << self
      # Since vireo4 now lets administrators design hierarchical organizational structures from which other
      # organizations can inherit, many institutions reconfigure the way vireo represents their organization
      # over what was expressed in vireo3.

      # This is used by MigrateSubmission5.rb to find the correct organization for a submission.

      # Because of this, the mapping between an organization and a degree level and other attributes
      # cannot be automatically determined.  The mappings must be expressed here by the person setting up
      # a migration.

      def siteSpecificOrg
        orgCat = getOrgCategory()
        college_category_id = orgCat.key("College")
        program_category_id = orgCat.key("Program")
        degree_category_id = orgCat.key("Degree")

#=begin
        if (VIREO::INSTITUTION == "JHU")
          institution_id = renameInstitution(orgCat, "Johns  Hopkins University")
          puts "INST ID " + institution_id.to_s

          #college_id = createOrganization("t", "Graduate School", college_category_id, institution_id)
          #createOrgChildrenOrg(institution_id, college_id)
          #createOrgAWS(college_id)

          #college_id = createOrganization("t", "Honors College", college_category_id, institution_id)
          #createOrgChildrenOrg(institution_id, college_id)
          #createOrgAWS(college_id)

        elsif (VIREO::INSTITUTION == "EXAMPLE2")
          institution_id = renameInstitution(orgCat, "Example Two University")
          puts "INST ID " + institution_id.to_s

          # CREATE TOP LEVEL
          college_id = createOrganization("t", "College of Arts and Sciences", college_category_id, institution_id)
          createOrgChildrenOrg(institution_id, college_id)
          createOrgAWS(college_id)
          program_id = createOrganization("t", "Museum Studies", program_category_id, college_id)
          createOrgChildrenOrg(college_id, program_id)
          createOrgAWS(program_id)

          college_id = createOrganization("t", "Honors College", college_category_id, institution_id)
          createOrgChildrenOrg(institution_id, college_id)
          createOrgAWS(college_id)
          program_id = createOrganization("t", "Honors Program", program_category_id, college_id)
          createOrgChildrenOrg(college_id, program_id)
          createOrgAWS(program_id)

          college_id = createOrganization("t", "Medical School", college_category_id, institution_id)
          createOrgChildrenOrg(institution_id, college_id)
          createOrgAWS(college_id)
          program_id = createOrganization("t", "Doctor of Elbow Science", program_category_id, college_id)
          createOrgChildrenOrg(college_id, program_id)
          createOrgAWS(program_id)
        end
#=end
        return institution_id
      end

      def siteSpecificOrgSearch(degreelevel, college, department, program)
        # DEGREE_LEVEL 1:Undergraduate, 2:Masters, 3:Doctoral
        orgCat = getOrgCategory();
        college_category_id = orgCat.key("College")
        program_category_id = orgCat.key("Program")
        school_category_id = orgCat.key("School")
        degree_category_id = orgCat.key("Degree")

        org = {}
#=begin
        if (VIREO::INSTITUTION == "JHU")
            org['organization_id'] = "1"
        end

        if (VIREO::INSTITUTION == "EXAMPLE")
          # 2: Graduate School, 3:Honors College
          if (degreelevel == nil)
            org['organization_id'] = "1"
          elsif (degreelevel.to_s == "1")
            org['organization_id'] = "3"
          elsif (degreelevel.to_s == "2")
            org['organization_id'] = "2"
          elsif (degreelevel.to_s == "3")
            org['organization_id'] = "2"
          else
            org['organization_id'] = "1"
          end
        elsif (VIREO::INSTITUTION == "EXAMPLE2")
          if (degreelevel == nil)
            org['organization_id'] = "1"
          elsif (degreelevel.to_s == "2")
            org['organization_id'] = "2"
          elsif (degreelevel.to_s == "3")
            org['organization_id'] = "4"
          else
            org['organization_id'] = "1"
          end
        end
#=end
        return org
      end
    end
  end
end
