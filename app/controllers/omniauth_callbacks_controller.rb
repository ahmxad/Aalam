# Where another service sends the person back after they signed in there
class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 20, within: 3.minutes, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def create
    auth = request.env["omniauth.auth"]
    return fail_login unless auth && auth.uid.present? && Identity::PROVIDER_NAMES.key?(auth.provider)

    identity = Identity.find_by(provider: auth.provider, uid: auth.uid.to_s)

    if authenticated?
      connect_to_signed_in_user(auth, identity)
    elsif identity
      sign_in_through(identity.user)
    else
      continue_without_identity(auth)
    end
  rescue ActiveRecord::RecordNotUnique
    fail_login
  end

  # The person pressed Cancel at the service, or something went wrong there
  def failure
    Rails.logger.warn("OmniAuth failure: #{params[:message]} (#{params[:strategy]})")
    fail_login
  end

  private
    def sign_in_through(user)
      start_new_session_for user
      # Someone who never proved their email address is taken to the page where they can do it
      redirect_to user.email_verified? ? after_authentication_url : email_verification_path
    end

    # Already signed in: the service is added to the account
    def connect_to_signed_in_user(auth, identity)
      user = Current.session.user
      name = Identity::PROVIDER_NAMES.fetch(auth.provider)

      if identity.nil?
        new_identity = user.identities.build(provider: auth.provider, uid: auth.uid.to_s)

        if new_identity.save
          redirect_to edit_account_path, notice: "#{name} is now connected to your account."
        else
          redirect_to edit_account_path, alert: new_identity.errors.full_messages.to_sentence
        end
      elsif identity.user_id == user.id
        redirect_to edit_account_path, notice: "#{name} was already connected to your account."
      else
        redirect_to edit_account_path, alert: "That #{name} account is already connected to a different account."
      end
    end

    def continue_without_identity(auth)
      email = verified_email(auth)
      existing = email && User.find_by(email_address: email)

      if existing&.email_verified?
        # The address was proved twice, here and at the service, so both belong to the same person
        connect_and_sign_in(existing, auth)
      else
        # An admin account is never removed this way
        existing.destroy if existing && !existing.admin?
        remember_pending_signup(auth, email)
        redirect_to new_oauth_signup_path
      end
    end

    def connect_and_sign_in(user, auth)
      identity = user.identities.build(provider: auth.provider, uid: auth.uid.to_s)

      if identity.save
        start_new_session_for user
        redirect_to after_authentication_url, notice: "#{identity.provider_name} is now connected to your account."
      else
        fail_login("That account already has a different #{identity.provider_name} account connected. Log in with your password instead.")
      end
    end

    # What the "Finish signing up" page needs. It lives in the session, which only this browser can read.
    def remember_pending_signup(auth, email)
      info = auth.info
      # Only a suggestion. GitHub has a nickname, Google does not, so the start of the email address is used.
      suggestion = info.nickname.presence || info.email.to_s.split("@").first.presence || info.name

      session[:pending_oauth] = {
        "provider" => auth.provider,
        "uid" => auth.uid.to_s,
        "email" => email,
        "name" => info.name.to_s.strip.first(50).presence,
        "username" => User.suggest_username(suggestion)
      }
    end

    # The email address that the service itself has verified, or nil.
    # GitHub only returns an address when it is the primary one and verified.
    # For Google the answer is checked here as well, because the address is what an account is matched on.
    def verified_email(auth)
      email = auth.info.email.presence
      return unless email
      return email unless auth.provider == "google_oauth2"

      email if auth.info.email_verified.in?([ true, "true" ])
    end

    def fail_login(message = "We could not sign you in with that service. Please try again or use another way to log in.")
      redirect_to new_session_path, alert: message
    end
end
