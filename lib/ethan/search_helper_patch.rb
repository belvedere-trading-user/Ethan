module Ethan
  module Patches
    module SearchHelperPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
      end

      module InstanceMethods
        def project_select_tag_for_ethan
          options = [[l(:label_project_all), 'all']]
          options << [l(:label_my_projects), 'my_projects'] unless User.current.memberships.empty?
          options << [l(:label_and_its_subprojects, @project.name), 'subprojects'] unless @project.nil? || @project.descendants.active.empty?
          options << [@project.name, ''] unless @project.nil?
          if !@project.nil? && !@project.descendants.active.empty? && !params.has_key?(:submit)
            default_choice = [l(:label_and_its_subprojects, @project.name), 'subprojects']
          else
            default_choice = params[:scope].to_s
          end
          label_tag("scope", l(:description_project_scope), :class => "hidden-for-sighted") +
          select_tag('scope', options_for_select(options, default_choice)) if options.size > 1
        end
      end
    end
  end
end

