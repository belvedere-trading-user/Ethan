require 'redmine'
  
Redmine::Plugin.register :ethan do
  name 'Ethan Search plugin'
  author 'Belvedere Trading'
  description 'A more serious Searcher for Redmine'
  version '0.1.0'

  Rails.configuration.to_prepare do
    require 'ethan/search_patch'
    unless SearchController.included_modules.include?(Ethan::Patches::SearchPatch)
      SearchController.send(:include, Ethan::Patches::SearchPatch)
    end
  end
end

