require 'will_paginate/array'

module Ethan
  module Patches
    module SearchPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          alias_method_chain :index, :improvements
        end
      end

      module InstanceMethods
        def index_with_improvements
          @question = params[:q] || ""
          @question.strip!
          @all_words = params[:all_words] ? params[:all_words].present? : true
          @titles_only = params[:titles_only] ? params[:titles_only].present? : false

          projects_to_search =
            case params[:scope]
            when 'all'
              nil
            when 'my_projects'
              User.current.memberships.collect(&:project)
            when 'subprojects'
              @project ? (@project.self_and_descendants.active.all) : nil
            else
              if !params.has_key?(:submit)
                @project ? (@project.self_and_descendants.active.all) : nil
              else
                @project
              end
            end

          offset = nil
          begin; offset = params[:offset].to_time if params[:offset]; rescue; end

          # quick jump to an issue
          if @question.match(/^#?(\d+)$/) && Issue.visible.find_by_id($1.to_i)
            redirect_to :controller => "issues", :action => "show", :id => $1
            return
          end

          @object_types = Redmine::Search.available_search_types.dup
          unless projects_to_search.nil?
           if (projects_to_search.is_a? Project) || (projects_to_search.one?)
             # don't search projects
             @object_types.delete('projects')
             # only show what the user is allowed to view
             @object_types = @object_types.select {|o| User.current.allowed_to?("view_#{o}".to_sym, projects_to_search)}
           end
          end

          if projects_to_search.nil?
            @trackers = Tracker.all
          else
            @trackers = []
            Array(projects_to_search).each do |project|
              (@trackers | [project.trackers]) if project.respond_to?('trackers')
              if project.respond_to?('trackers')
                project.trackers.each do |tracker|
                  @trackers.push(tracker) unless @trackers.include?(tracker)
                end
              end
            end
          end

          @scope = @object_types.select {|t| params[t]}
          @scope = @object_types if (@scope.empty? )

          # extract tokens from the question
          # eg. hello "bye bye" => ["hello", "bye bye"]
          @tokens = @question.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
          # tokens must be at least 2 characters long
          @tokens = @tokens.uniq.select {|w| w.length > 1 }

          @selected_trackers = @trackers.select {|t| params[t.name] }
          @selected_trackers = @trackers if (@selected_trackers.empty? && @scope.any? {|s| s.singularize == "issue" })

          if !@tokens.empty?
            # no more than 5 tokens to search for
            @tokens.slice! 5..-1 if @tokens.size > 5

            @results = []
            @results_by_type = Hash.new {|h,k| h[k] = 0}

            @scope.each do |s|
              model = s.singularize.camelcase.constantize
              if s.singularize == "issue"
                model = model.where("tracker_id IN (?)", @selected_trackers)
              end
              r, c = model.search(@tokens, projects_to_search,
                :all_words => @all_words,
                :titles_only => @titles_only,
                :offset => offset,
                :before => params[:previous].nil?)
              @results += r
              @results_by_type[s] += c
            end
            @results = @results.sort {|a,b| b.event_datetime <=> a.event_datetime}
            @results = @results.paginate(:page => params[:page])
          else
            @question = ""
          end
          render :layout => false if request.xhr?

        end
      end
    end
  end
end
