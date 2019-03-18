require 'test_helper'

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @image_file = file_fixture_copy("test.jpg")
  end

  teardown do
    File.unlink(@image_file) if File.exist?(@image_file)
  end

  test "webhook call should create request using job" do
    perform_enqueued_jobs do
      post "/webhooks/requests_create", params: wpcf7_params
      assert_response :success
    end

    assert_not_nil Request.joins(:user).where(users: { email: wpcf7_params[:email] }).first
  end

  test "webhook call should create request with an attached image" do
    perform_enqueued_jobs do
      post "/webhooks/requests_create", params: wpcf7_params.merge(art_sample_1: @image_file)
      assert_response :success
    end

    request = Request.joins(:user).where(users: { email: wpcf7_params[:email] }).first
    assert request.images.count == 1
    assert request.images.first.decorate.exists?
  end

end
