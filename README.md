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
- #F8E5D2
- #9E483F
- #EE9C44