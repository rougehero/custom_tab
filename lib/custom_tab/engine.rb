require 'deface'
require 'custom_tab'
require 'deface'

module CustomTab
  class Engine < ::Rails::Engine
    engine_name 'custom_tab'

    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/overrides"]

    # Add any db migrations
    initializer 'custom_tab.load_app_instance_data' do |app|
      CustomTab::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'custom_tab.register_plugin', :before => :finisher_hook do |_app|
      Foreman::Plugin.register :custom_tab do
        requires_foreman '>= 1.4'

        # Add permissions
        security_block :custom_tab do
          permission :view_custom_tab, :'custom_tab/hosts' => [:new_action]
        end

        # Add a new role called 'Discovery' if it doesn't exist
        role 'CustomTab', [:view_custom_tab]

        # add menu entry
        menu :top_menu, :template,
             url_hash: { controller: :'custom_tab/hosts', action: :new_action },
             caption: 'CustomTab',
             parent: :hosts_menu,
             after: :hosts

        # add dashboard widget
        widget 'custom_tab_widget', name: N_('Foreman plugin template widget'), sizex: 4, sizey: 1
      end
    end

    # Precompile any JS or CSS files under app/assets/
    # If requiring files from each other, list them explicitly here to avoid precompiling the same
    # content twice.
    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end
    initializer 'custom_tab.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end
    initializer 'custom_tab.configure_assets', group: :assets do
      SETTINGS[:custom_tab] = { assets: { precompile: assets_to_precompile } }
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      begin
        Host::Managed.send(:include, CustomTab::HostExtensions)
        HostsHelper.send(:include, CustomTab::HostsHelperExtensions)
      rescue => e
        Rails.logger.warn "CustomTab: skipping engine hook (#{e})"
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        CustomTab::Engine.load_seed
      end
    end

    initializer 'custom_tab.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../../..', __FILE__), 'locale')
      locale_domain = 'custom_tab'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
