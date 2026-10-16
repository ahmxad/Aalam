Current structure:

#### CONTROLLERS:
- Always use plural (exeption for static pages eg. Home)
- But create one single Controller for static pages (eg. Pages)

#### VIEWS:
- Home (folder name), index(file name)

#### MODELS:
- Nothing (to check run: ApplicationRecord.descendants.map(&:name).sort)
- Always generate in singular form


#### Current structure:
- Controlers:
- - Home(index), Explore(index), Contact(index)

- Views:
- - Home, Explore, Contact

#### Colors:
- #000000
- #ffffff
- #494949
- #7c7a7a
- #ff5d73



#### Git:
> make new branch for a feature
- make: git switch -c branch-name
- show on github: git push -u origin branch-name
> after deleting a branch (IF YOU DELETED FROM GITHUB)
- change branch: git checkout main
- git pull
- git branch -d branch-name
- git fetch --prune
> rails specific (after switching to main)
- bundle install
- bin/rails db:migrate
- bin/rails test
- bin/rubocop
- bin/importmap audit
- bin/brakeman --no-pager