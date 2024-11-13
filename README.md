# Rails templates

Generate a rails app with some default template

## Basic (docker for postgre, use a structure.sql file and vite to compile frontend)

```````
rails new \ 
    -m https://raw.githubusercontent.com/Charles-Delannoy/rails_template/main/basic.rb \
    --minimal \
    --no-skip-hotwire \
    --no-skip-active-record \
    -d postgresql \
    YOUR_RAILS_APP_NAME
```````
