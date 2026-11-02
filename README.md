# Aalam

A personal blog built with Rails 8. Readers can browse posts by topic and card, and signed-in readers can like, save, comment, reply and share. An admin area manages topics, cards and posts.

<!--
Screenshots: add your images to the screenshots/ folder, then remove this comment.

![Home page](screenshots/home.png)
![Post page with comments](screenshots/post.png)
![Profile](screenshots/profile.png)
![Account settings](screenshots/account.png)
-->

## Features

**Blog**
- Topics, cards and posts with Markdown rendering, search, and slugs that keep old URLs working with a redirect
- Images are converted to WebP (topic and card images on the server, post images in the browser before upload)

**Accounts**
- Sign up with username, email, password and avatar; log in with either username or email
- Live username availability check and password strength meter
- Avatars are converted to 512x512 WebP
- Log in with GitHub or Google (OmniAuth)
- Email verification with a 6 digit code (expires after 10 minutes, limited attempts and resends); accounts that stay unverified for 24 hours are deleted by a recurring job
- Change email (code sent to the new address, notice sent to the old one), set or change a password, connect or disconnect GitHub and Google
- Public profile pages and account settings
- Delete your own account, confirmed by typing your username

**Engagement**
- Like, save and share posts
- Comments with replies, comment likes, sorting, "load more" and delete
- Unverified users cannot like, save or comment

**Other**
- Contact form that emails the site owner (messages are not stored)
- Privacy Policy and Terms of Use pages
- Rate limits on sign in, account actions and engagement
- Strict Content Security Policy

## Stack

- Ruby 4.0.6, Rails 8.1.4
- PostgreSQL
- Hotwire (Turbo and Stimulus) with importmap
- Tailwind CSS v4 and daisyUI, Propshaft
- Solid Queue and Solid Cache
- Active Storage (local disk in development, Cloudflare R2 in production)
- Lenis and GSAP for scrolling and animation
- Minitest and Capybara for tests

## Getting started

You need [mise](https://mise.jdx.dev) (or another way to install Ruby 4.0.6) and a running PostgreSQL server.

```bash
git clone git@github.com:ahmxad/Aalam.git
cd Aalam
mise install
bin/setup
```

`bin/setup` installs the gems, creates the database, and starts the development server. Later, start the server with `bin/dev`. Then open http://127.0.0.1:3000.

Emails in development are not sent. Open http://127.0.0.1:3000/letter_opener to read them, for example the verification codes.

### Credentials

Secrets are stored in encrypted Rails credentials, and the key files are never committed. The repository contains the encrypted files, but not the keys to open them, so create your own development credentials:

```bash
rm config/credentials/development.yml.enc
bin/rails credentials:edit --environment development
```

Sign in with GitHub or Google needs your own OAuth apps. Add their keys under `github:` and `google:` (`client_id` and `client_secret`) in that file. Without them, the social login buttons will not work, but the rest of the app does.

## Tests

```bash
bin/rails test          # unit, controller and integration tests
bin/rails test:system   # browser tests (needs Chrome)
```

## Production

The app ships with a `Dockerfile` and a Kamal configuration. Production settings come from the credentials, so nothing is hard coded:

- `site`: `host`, `contact_email`, `mail_from`
- `smtp`: `address`, `port`, `user_name`, `password`
- `r2`: `account_id`, `access_key_id`, `secret_access_key`, `bucket` (uploads go to the local disk when these are not set)

Background jobs run inside Puma when `SOLID_QUEUE_IN_PUMA` is set, which suits a single small server.


> It's ready to go live but the hosting is too much expensive bro.