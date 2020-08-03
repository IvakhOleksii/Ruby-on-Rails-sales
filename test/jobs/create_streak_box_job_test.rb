# frozen_string_literals: true

require "test_helper"

class CreateStreakBoxJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @previous_create_value = Settings.streak.create_boxes
    Settings.streak.create_boxes = true
    @request = requests(:fresh)
  end

  teardown do
    Settings.streak.create_boxes = @previous_create_value
  end

  test "should create a box with the correct attributes" do
    CreateStreakBoxJob.perform_now(@request)
    assert_not_nil @request.streak_box_key
    box = MostlyStreak::Box.find(@request.streak_box_key)
    assert_equal @request.description, box.notes
  end

  test "should send start_design email" do
    Settings.emails.deliver_start_design = true
    assert_emails 1 do
      perform_enqueued_jobs do
        CreateStreakBoxJob.perform_now(@request)
      end
    end
  end

  test "should send to lee when don't know size" do
    Settings.emails.deliver_start_design = true
    Settings.emails.auto_quote_enabled = true
    @request.size = "Don't Know"
    assert_emails 1 do
      perform_enqueued_jobs do
        CreateStreakBoxJob.perform_now(@request)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, "leeroller@customtattoodesign.ca"
  end

  test "should send to lee when don't know style" do
    Settings.emails.deliver_start_design = true
    Settings.emails.auto_quote_enabled = true
    @request.style = "Don't Know"
    assert_emails 1 do
      perform_enqueued_jobs do
        CreateStreakBoxJob.perform_now(@request)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, "leeroller@customtattoodesign.ca"
  end

  test "should send to sales with known size" do
    Settings.emails.deliver_start_design = true
    Settings.emails.auto_quote_enabled = true
    @request.update_columns size: TattooSize.find_by(size: 1).name,
                            style: Request::TATTOO_STYLES.first
    assert_emails 1 do
      perform_enqueued_jobs do
        CreateStreakBoxJob.perform_now(@request)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, "sales@customtattoodesign.ca"
  end
end