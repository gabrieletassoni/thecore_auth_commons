class ApplicationController < ActionController::Base
  # Host apps read current_user in before_actions that also run on the Devise controllers
  # (thecore_ui_commons <= 3.4.0 did, in reject_locked!): on the sign-in POST that runs the password strategy
  # before SessionsController#create does. Kept here so the tests see the same order.
  before_action { current_user }
end
