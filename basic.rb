run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Docker for PG
run 'touch docker-compose.yml'
require 'yaml'
docker_config = {
    'services' => {
        'postgres' => {
            'image' => 'postgres:15.8-alpine3.19',
            'mem_limit' => '256m',
            'volumes' => ['postgresql:/var/lib/postgresql/data'],
            'ports' => ["5434:5432"],
            'environment' => ["POSTGRES_USER=#{@app_name}", "POSTGRES_PASSWORD=#{@app_name}_pg_passwd"]
        }
    },
    'volumes' => {
        'postgresql' => {
        }
    }
}
File.write("docker-compose.yml", docker_config.to_yaml[0..-4].gsub("5434:5432", '"5434:5432"'))

# database config
yaml_db_config = File.read("config/database.yml")
partitioned_db_config = yaml_db_config.partition("default: &default\n")
partitioned_db_config.insert(2,
    "  username: <%= ENV['POSTGRES_USER'] %>\n  password: <%= ENV['POSTGRES_PASSWORD'] %>\n  port: <%= ENV['DATABASE_PORT'] || \"5432\" %>\n  host: <%= ENV['DATABASE_HOST'] || \"127.0.0.1\" %>\n")
yaml_db_config = partitioned_db_config.join
File.write("config/database.yml", yaml_db_config)


# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "bootstrap", "~> 5.2"
    gem "autoprefixer-rails"
    gem "font-awesome-sass", "~> 6.1"
    gem "simple_form", github: "heartcombo/simple_form"
    gem "sassc-rails"

  RUBY
end

inject_into_file "Gemfile", before: "group :development, :test do" do
    <<~RUBY
      # build front with vite for rails
      gem 'vite_rails'

    RUBY
  end

  inject_into_file "Gemfile", after: "group :development, :test do" do
    "\n  gem \"dotenv-rails\""
  end

# Assets
########################################
run "rm -rf app/assets/stylesheets"
run "rm -rf vendor"
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/master.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-master/README.md"
run "mv app/assets/rails-stylesheets-master app/assets/stylesheets"


# Use a structure.sql file
########################################
inject_into_file "config/application.rb", after: "  class Application < Rails::Application" do
    <<~RUBY
        # Use a sql db structure file
        config.active_record.schema_format = :sql
    RUBY
end

# Layout
########################################
gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

after_bundle do
  run 'bundle exec vite install'
  run 'docker compose up -d'
  rails_command "db:drop db:create db:migrate"
  generate("simple_form:install", "--bootstrap")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")


  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT

    # Ignore .env file containing credentials.
    .env*

    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Bootstrap & Popper
  ########################################
  append_file "config/importmap.rb", <<~RUBY
    pin "bootstrap", to: "bootstrap.min.js", preload: true
    pin "@popperjs/core", to: "popper.js", preload: true
  RUBY

  append_file "config/initializers/assets.rb", <<~RUBY
    Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
  RUBY

  append_file "app/javascript/application.js", <<~JS
    import "@popperjs/core"
    import "bootstrap"
  JS

  append_file "app/assets/config/manifest.js", <<~JS
    //= link popper.js
    //= link bootstrap.min.js
  JS

  # Heroku
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Rubocop
  ########################################
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'Basic template from https://raw.githubusercontent.com/Charles-Delannoy/rails_template/main/basic.rb'"
end
